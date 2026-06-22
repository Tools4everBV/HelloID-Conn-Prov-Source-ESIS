# HelloID-Conn-Prov-Source-ESIS

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/rovictesis-logo.png">
</p> 

## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Prerequisites](#Prerequisites)
  + [Remarks](#Remarks)
- [Setup the connector](@Setup-The-Connector)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Source-ESIS_ is a _source_ connector. ESIS provides a SOAP webservice that allows you to programmatically interact with it's data. The HelloID connector uses the SOAP actions listed in the table below. This connector adds Student and group information in HelloID.

| Endpoint     | Description |
| ------------ | ----------- |
|  HaalLeerlinggegevens  |  Contains all Student, School, Location, Group and Teacher Data       |

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting           | Description                        | Mandatory   |
| ------------      | -----------                        | ----------- |
| BaseUrl           | The URL to the webservice          | Yes         |
| AuthBrinKeys      | Authorization key per brin for the webservice | Yes         |
| Klantcode         | -                                  | Yes         |
| Klantnaam         | -                                  | Yes         |
| CertificateBase64 | Base 64 encoded certificate        | No         |
| Certpath          | Fullpath to the Certifcate (.p12)  | No         |
| Certpassword      | Certificate passwword              | Yes         |
| Xsdversie         | Default 1                          | No         |

### Prerequisites
 - A Certificate to authenticate with the webservice (.p12)
 - The Mandatory field from the connector Settings.


### Remarks
 - Active Other groups and Instructiongroups are delivered by the connector when the property “In koppelingen beschikbaar” In ESIS at the group is marked as Yes. The groups can be found in the node subgroups.
 - The connector only retrieves the students of the current Schoolyear, so it is not able to retrieve from the past and upcoming students.
 - A certificate and password can by requested at ROVICT 
 - The authorization keys can be created in Esis itself
 - The format for the authorization keys is json: [{"brin":"12AB.00","key":"KEY1"},{"brin":"34CD.00","key":"KEY2"}]

## Setup the connector

> _How to setup the connector in HelloID._ Are special settings required. Like the _primary manager_ settings for a source connector.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
