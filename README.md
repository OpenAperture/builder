# OpenAperture.Builder

[![Build Status](https://semaphoreci.com/api/v1/projects/f7e72642-032f-437e-b89d-401014147e5c/399299/badge.svg)](https://semaphoreci.com/perceptive/builder)

The Builder module provides a standardized mechanism to execute build configurations and docker builds for Workflows that are orchestrated through the OpenAperture system.

## Module Responsibilities

The WorkflowOrchestrator module is responsible for the following actions within OpenAperture:

* Reading and updating the deployment repository associated with Workflows
* Executing Docker builders

## Messaging / Communication

The following message(s) may be sent to the Builder.  A Workflow is a OpenAperture construct that can be created/retrieved at /workflow.

* Builder
	* Queue:  builder
	* Payload (Map)
		* force_build 
		* db field:  workflow_id (same as id)
		* db field:  id
		* db field:  deployment_repo
		* db field:  deployment_repo_git_ref
		* db field:  source_repo 
		* db field:  source_repo_git_ref
		* db field:  milestones [:build, :deploy]
		* db field:  current_step 
		* db field:  elapsed_step_time 
		* db field:  elapsed_workflow_time
		* db field:  workflow_duration
		* db field:  workflow_step_durations
		* db field:  workflow_error 
		* db field:  workflow_completed
		* db field:  event_log
		* notifications_exchange_id
		* notifications_broker_id
		* orchestration_exchange_id
		* orchestration_broker_id
		* docker_build_etcd_token

## Module Configuration

The following configuration values must be defined either as environment variables or as part of the environment configuration files:

* Current Exchange
	* Type:  String
	* Description:  The identifier of the exchange in which the Orchestrator is running
  * Environment Variable:  EXCHANGE_ID
* Current Broker
	* Type:  String
	* Description:  The identifier of the broker to which the Orchestrator is connecting
  * Environment Variable:  BROKER_ID
* Manager URL
  * Type: String
  * Description: The url of the OpenAperture Manager
  * Environment Variable:  MANAGER_URL
  * Environment Configuration (.exs): :openaperture_manager_api, :manager_url
* OAuth Login URL
  * Type: String
  * Description: The login url of the OAuth2 server
  * Environment Variable:  OAUTH_LOGIN_URL
  * Environment Configuration (.exs): :openaperture_manager_api, :oauth_login_url
* OAuth Client ID
  * Type: String
  * Description: The OAuth2 client id to be used for authenticating with the OpenAperture Manager
  * Environment Variable:  OAUTH_CLIENT_ID
  * Environment Configuration (.exs): :openaperture_manager_api, :oauth_client_id
* OAuth Client Secret
  * Type: String
  * Description: The OAuth2 client secret to be used for authenticating with the OpenAperture Manager
  * Environment Variable:  OAUTH_CLIENT_SECRET
  * Environment Configuration (.exs): :openaperture_manager_api, :oauth_client_secret
* System Module Type
	* Type:  atom or string
	* Description:  An atom or string describing what kind of system module is running (i.e. builder, deployer, etc...)
  * Environment Configuration (.exs): :openaperture_overseer_api, :module_type
* Dockerhub Registry URL
	* Type:  String
	* Description:  By default, the Builder will push to a registry.  This is the URL for that registry, defaults to dockerhub.
	* Environment Variable:  DOCKER_REGISTRY_URL	
  * Environment Configuration (.exs): :openaperture_builder, :docker_registry_url
* Docker Registry Username
	* Type:  String
	* Description:  By default, the Builder will push to a registry.  This is the username for that registry, defaults to dockerhub.
	* Environment Variable:  DOCKER_REGISTRY_USERNAME	
  * Environment Configuration (.exs): :openaperture_builder, :docker_registry_username
* Docker Registry Email
	* Type:  String
	* Description:  By default, the Builder will push to a registry.  This is the email for that registry, defaults to dockerhub.
	* Environment Variable:  DOCKER_REGISTRY_EMAIL	
  * Environment Configuration (.exs): :openaperture_builder, :docker_registry_email
* Docker Registry Password
	* Type:  String
	* Description:  By default, the Builder will push to a registry.  This is the password for that registry, defaults to dockerhub.
	* Environment Variable:  DOCKER_REGISTRY_PASSWORD	
  * Environment Configuration (.exs): :openaperture_builder, :docker_registry_password
* Github OAuth Credentials
	* Type:  String
	* Environment Variable:  GITHUB_OAUTH_TOKEN
	* Description:  For private repositories, specify a Github OAuth token with access to those repositories
  * Environment Configuration (.exs): :github, :user_credentials

## Building & Testing

### Building

The normal elixir project setup steps are required:

```iex
mix do deps.get, deps.compile
```

To startup the application, use mix run:

```iex
MIX_ENV=prod elixir --sname builder -S mix run --no-halt
```

### Testing 

You can then run the tests

```iex
MIX_ENV=test mix test test/
```