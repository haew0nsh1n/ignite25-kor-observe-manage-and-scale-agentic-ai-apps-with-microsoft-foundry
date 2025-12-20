# Using AI Agents in Azure AI Foundry

Our objective is to build Cora, an AI shopping assistant for Zava that:
- answer customer questions in a _polite, helpful tone_.
- provides _factual responses_ about products and inventory.
- computes _personalized discounts_ based on customer, cart and inventory.

In this section, we'll see how we can build this solution using AI Agents with the Azure AI Foundry platform.

## 1. What is Azure AI Foundry?

Azure AI Foundry is a unified Azure _platform-as-a-service_ offering for enterprise AI operations, model builders, and app development. It unifies _agents, models, and tools_, under a single management grouping - with observability features like tracing, monitoring, evaluations, and red-teaming built-in · [Learn More](https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry)


## 2. What is an AI Agent?

While _AI assistants_ focus on supporting human interactions, _AI agents_ focus on **autonomy** - with the ability to take decisions, invoke tools, or participate in workflows, in order to reach the desired goal. An AI Agent has three components:

- **Model (LLM):** Powers language understanding and reasoning.
- **Instructions:** Defines agent goals, behavior, and constraints.
- **Tools:** Allows agents to retrieve knowledge or take action.


![Azure AI Foundry](./../assets/01-what-is-an-agent.png)

In our scenario, _Cora_ is an AI assistant that Zava customers can interact with. Under the hood, Cora's functionality can be implemented by one or more agents - which help compose and coordinate the final response to the user. For instance:

1. Customer Support Agent - generates the polite, helpful response
1. Product Inventory Agent - returns product & inventory information
1. Customer Loyaly Agent - computes personalized discount on checkout

In each case, we need to _select_ the right model for that task, _define_ the agent's instructions for processing inputs and returning responses, and _declare_ tools that the agent can access to help it execute that task. For example:

- Product Agent - must return factual and precise information
- It has access to - knowledge tools like file search & AI search
- It uses - a chat model to generate response grounded in knowledge

## 3. What is Azure AI Agent Service?

The Azure AI Foundry Agent Service connects core pieces of the Azure AI Foundry platform (e.g., models, tools, frameworks) into a _unified runtime for agents_. It oversees agent operations across development, deployment, and production - managing threads, orchestrating tool calls, enforcing content safety, integrating observability etc. - for secure, scalable and reliable solutions · [Learn More](https://learn.microsoft.com/azure/ai-foundry/agents/overview)

![Azure AI Foundry](./../assets/01-azure-agent-service.png)

At the center of this system is Azure AI Foundry Agent Service, enabling the operation of agents across development, deployment, and production. 

## 4. How do AI Agents Work in Foundry?

Think of Azure AI Foundry as _the agent factory_ with an assembly line of tools and services to streamline agent creation, deployment, and maintenance  · [Learn More](https://learn.microsoft.com/azure/ai-foundry/agents/overview#how-do-agents-in-ai-foundry-work)

![Azure AI Foundry](./../assets/01-how-do-agents-work.png)

1. **Model Selection** - start by selecting the model that gives agent the right reasoning and language understanding capabilities for the task.
1. **Model Customization** - shape the model to suit your needs. Use fine-tuning, distillation, or domain-specific prompts to refine behaviors.
1. **Tool Integration** - equip agent with tools to retrieve knowledge or take relevant actions that can engineer context or extend model capabilities.
1. **Lifecycle Orchestration** - manage agent threads, tool calls, logs and more, to streamline and coordinate task execution.
1. **Observability** - monitor and test agent execution at every step with logs, traces, and evaluation metrics - to analyze and improve performance.
1. **Trust** - benefit from enterprise-grade platform features like managed identity, role-based access, content filters, network isolation and more.

_In this workshop, we'll trace the AI agent journey from model selection to customization, observability and deployment to production - and discuss tools & orchestration in the context of developing our Core chatbot_.

