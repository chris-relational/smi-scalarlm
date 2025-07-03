-- Create the Snowflake resources for the SPCS services
-- 

use role accountadmin;

create role if not exists scalarlm_spcs_role;
use role scalarlm_spcs_role;

-- create a db to hold a warehouse (for sql ddl/dml) and a compute pool (for the docker container)
-- 
create database if not exists scalarlm_spcs_db;
grant ownership on database scalarlm_spcs_db to role scalarlm_spcs_role copy current grants;

-- create a compute engine for sql
create or replace warehouse scalarlm_spcs_wh with warehouse_size='x-small';
grant usage on warehouse scalarlm_spcs_wh to role scalarlm_spcs_role;

-- BIND SERVICE ENDPOINT priviledge: required priviledge for SPCS services exposing endpoints to 
-- to external services (incl. public).
-- 1. BIND SERVICE ENDPOINT = "ability to open service endpoints to external callers"
-- 2. ON ACCOUNT = "grant this privilledge on all the databases, registries, warehouses and compute pools
--    of the SF account (here RAI_PROD_GEN_AI_AWS_US_WEST_2_CONSUMER)"
-- 3. TO ROLE = "grant this privilledge to the role"
grant bind service endpoint on account to role scalarlm_spcs_role;

-- Create a compute engine for docker containers
create compute pool scalarlm_spcs_cp
min_nodes = 1
max_nodes = 1
instance_family = cpu_x64_xs;
grant usage, monitor on compute pool scalarlm_spcs_cp to role scalarlm_spcs_role;

-- The grantee creates the following objects
-- 
create schema if not exists scalarlm_spcs_schema;
grant usage on schema scalarlm_spcs_schema to scalarlm_spcs_role;

create image repository if not exists scalarlm_spcs_repository;

create stage if not exists scalarlm_scpsc_stage
directory = ( enable = true );

-- Normally, the grantee of the role is different
grant role scalarlm_spcs_role to user chris_malliopoulos;
