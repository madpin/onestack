-- Create databases
CREATE DATABASE litellm;
CREATE DATABASE casdoor;

-- Create schemas for other services that share databases
CREATE SCHEMA IF NOT EXISTS langfuse;
CREATE SCHEMA IF NOT EXISTS librechat;
CREATE SCHEMA IF NOT EXISTS ttrss;
