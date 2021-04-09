## What is Biceps of Steel

Biceps of Steel is intended as a repository providing Bicep templates for quickly deploying relatively common Azure application deployment patterns. The objective is to focus on the various levels of security an application might want.

Each of the templates deploy a Cosmos Database, Event Hub and Serive Bus Namespace that are all used by an Azure Function app.

At the simplest level, the template configures all of the connectivity to internal resources to use Managed Identities. This means there's no secrets required anywhere. Gone are the days of key management and having to worry about key rotation policies. Azure AD RBAC is used to make everything work seemlessly.

The next level is to deploy using Azure Function Premium and deploy all of the storage layers behind a vnet. This will leave just the Azure Function API layer as attack surface.

And then finally we'll add a gateway so that even the function app itself is nicely hidden away behind the vnet as well. This keeps the attack surface as small as possible.