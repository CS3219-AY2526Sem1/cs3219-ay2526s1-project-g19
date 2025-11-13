[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/QUdQy4ix)

# PeerPrep - Collaborative Coding Platform

**CS3219 Project AY2024/25 Semester 1 | Group G19**

PeerPrep is a collaborative coding platform designed to help engineers prepare for technical interviews through peer-to-peer practice sessions. The platform supports peer matching, real-time collaborative code editing, live chat communication, and code execution functionalities.

This project is developed for academic purposes as part of CS3219 Software Engineering Principles and Patterns course at the National University of Singapore.

---
## Table of Contents

- [Key Features](#key-features)
  - [Matching Feature](#matching-feature)
  - [Collaborative Sessions](#collaborative-sessions)
  - [Question Lists](#question-lists)
  - [User Profiles](#user-profiles)
- [Implementation Details](#implementation-details)
  - [System Architecture](#system-architecture)
  - [Tech Stack](#tech-stack)
    - [Frontend](#frontend)
    - [Backend Services](#backend-services)
    - [Development Tools](#development-tools)
- [Additional Documentation](#additional-documentation)
  - [API Documentation](#api-documentation)
- [Acknowledgments](#acknowledgments)

---
## Key Features
### Matching Feature
- Match with peers based on:
  - Question topic selections
  - Primary and secondary programming language preferences
  - Question difficulty level

### Collaborative Sessions
- Real-time synchronized code editing
- Support for multiple programming languages including:
  - Python
  - Java
  - C/C++
  - JavaScript
- Supports code execution and testing
- Provide real-time messaging with collaboration partners

### Question Lists
- Provide comprehensive question bank for practice for solo preparation
- Questions categorized by:
  - Topics
  - Difficulty level
- Supports code execution and testing

### User Profiles
- Personal profile management
- Provide session history with statistics
- Account settings and password management

---

## Implementation Details

### System Architecture

PeerPrep follows a **microservices architecture** with event-driven communication patterns.

### Tech Stack

### Frontend
- **Framework**: React 19.1.1
- **Build Tool**: Vite 7.1.12
- **Routing**: React Router DOM 7.9.3
- **Styling**: TailwindCSS 3.4.18
- **Code Editor**: CodeMirror 6 with multi-language support
- **HTTP Client**: Axios 1.12.2
- **Real-time**: Socket.IO Client 4.8.1
- **Icons**: Lucide React 0.544.0

### Backend Services

#### Python Services
- **Django Services**: Django 5.2.6 + Django REST Framework 3.15.2-3.16.1
  - Question Service
  - User Service  
  - Execution Service
- **FastAPI Services**: FastAPI 0.118.0-0.119.0
  - Matching Service
  - Session Service
  - Chat Service
  - Collaboration Service
- **Python Versions**: Python 3.10 and 3.13

#### Databases
- **PostgreSQL**: Primary relational database for user, question, and session data
- **Redis**: In-memory data store for matching queues and caching

#### Message Broker
- **Apache Kafka**: Event streaming platform (Confluent Platform 8.1.0)

#### Containerization
- **Docker**: Container runtime
- **Docker Compose**: Multi-container orchestration

#### Deployment
- **Terraform**: Infrastructure as Code
- **AWS**: Cloud platform
  - ECS (Elastic Container Service)
  - EC2 (Elastic Compute Cloud)
  - RDS (Relational Database Service)
- **Nginx**: Reverse proxy and load balancer

### Development Tools
- **Version Control**: Git + GitHub
- **Environment Management**: python-decouple, dotenv
- **API Documentation**: drf-spectacular, OpenAPI/Swagger

---
## Additional Documentation

Additional documentation can be found in the `docs/` directory:

### API Documentation

Each service exposes interactive API documentation:

- Question Service: http://localhost:8001/api/docs/
- User Service: http://localhost:8000/api/docs/
- Execution Service: http://localhost:8006/api/docs/
- Matching Service: http://localhost:8002/docs
- Session Service: http://localhost:8003/docs

## Acknowledgments
- AI tools (ChatGPT, Claude, GitHub Copilot, Cursor, Gemini, Lovable) are used to assist in various tasks that enhanced development productivity, details can be found in [AiUsage.md](AiUsage.md)
