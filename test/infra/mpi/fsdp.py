import torch
import torch.nn as nn
from mpi4py import MPI
import numpy as np

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
world_size = comm.Get_size()

torch.manual_seed(42)

class FSDPLayer(nn.Module):
    def __init__(self, layer):
        super().__init__()
        self.layer = layer
        self.rank = rank
        self.world_size = world_size

    def all_gather(self, tensor):
        if tensor is None:
            return None
        tensor_numpy = tensor.detach().numpy()
        gathered = np.zeros([self.world_size] + list(tensor_numpy.shape), dtype=tensor_numpy.dtype)
        comm.Allgather(tensor_numpy, gathered)
        return torch.from_numpy(gathered).to(tensor.device)

    def forward(self, x):
        if hasattr(self.layer, 'weight'):
            full_weight = self.all_gather(self.layer.weight)
            self.layer.weight.data = full_weight[self.rank]
        if hasattr(self.layer, 'bias'):
            full_bias = self.all_gather(self.layer.bias)
            self.layer.bias.data = full_bias[self.rank]
        return self.layer(x)

    def synchronize_gradients(self):
        def reduce_scatter(param):
            if param.grad is not None:
                grad = param.grad.data
                local_size = grad.numel() // self.world_size
                start = self.rank * local_size
                end = start + local_size if self.rank < self.world_size - 1 else grad.numel()
                
                local_grad = torch.zeros(end - start, dtype=grad.dtype, device=grad.device)
                comm.Reduce_scatter(grad.view(-1).numpy(), local_grad.numpy(), op=MPI.SUM)
                
                grad.view(-1)[start:end] = local_grad
                grad /= self.world_size
                param.grad.data = grad

        if hasattr(self.layer, 'weight'):
            reduce_scatter(self.layer.weight)
        if hasattr(self.layer, 'bias'):
            reduce_scatter(self.layer.bias)

class FSDPModel(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.layers = nn.ModuleList(self._get_fsdp_layers(model))

    def _get_fsdp_layers(self, model):
        return [FSDPLayer(module) for module in model.modules() if self._is_leaf_module(module)]

    @staticmethod
    def _is_leaf_module(module):
        return not list(module.children())
    
    def forward(self, x):
        for layer in self.layers:
            x = layer(x)
        return x

    def backward(self, loss):
        loss.backward()
        for layer in reversed(self.layers):
            layer.synchronize_gradients()

def main():
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    model = nn.Sequential(
        nn.Linear(10, 20),
        nn.ReLU(),
        nn.Linear(20, 5)
    ).to(device)
    
    fsdp_model = FSDPModel(model)
    
    optimizer = torch.optim.SGD(fsdp_model.parameters(), lr=0.01)
    for epoch in range(10):
        input_data = torch.randn(32, 10, device=device)
        output = fsdp_model(input_data)
        
        target = torch.randn(32, 5, device=device)
        loss = nn.functional.mse_loss(output, target)
        
        optimizer.zero_grad()
        fsdp_model.backward(loss)
        optimizer.step()
        
        if rank == 0:
            print(f"Epoch {epoch}, Loss: {loss.item()}")

if __name__ == "__main__":
    main()

# mpirun --allow-run-as-root -np 2 --oversubscribe python fsdp.py
