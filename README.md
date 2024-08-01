# KORE's OpenAPI Specification

This repository contains [OpenAPI](https://www.openapis.org/) documents for [KORE's API](https://docs.korewireless.com/).

Files can be found in the json/ and yaml/ directories.

## What Is OpenAPI?

From the [OpenAPI Specification](https://github.com/OAI/OpenAPI-Specification):

> The OpenAPI Specification (OAS) defines a standard, programming language-agnostic interface document for HTTP APIs, which allows both humans and computers to discover and understand the capabilities of a service without requiring access to source code, additional documentation, or inspection of network traffic. When properly defined via OpenAPI, a consumer can understand and interact with the remote service with a minimal amount of implementation logic. Similar to what interface documentation have done for lower-level programming, the OpenAPI Specification removes guesswork in calling a service.

## How To Add OpenAPISpec to Gitbook
You can follow the guide provided in the official Gitbook [documentation](https://docs.gitbook.com/content-editor/blocks/openapi) page.

#### How to hide the Test-It option in Gitbook.
Add the below line of code at the root level of your OpenAPISpec
``
x-hideTryItPanel : false
``
#### How to hide the code samples section from Gitbook.
Add the below line of code at the root level of your OpenAPISpec
``
x-codeSamples: false
``