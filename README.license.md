# nDPI Licensing Terms and Component Usage

This document outlines the licensing conditions for the nDPI library and its associated components based on your project's intended use.
The nDPI library is released under LGPLv3 with the exception of some protocol dissectors that are licensed under a dual license.

## Core Library License
The core **nDPI library** is open-source and released under the **GNU Lesser General Public License v3 (LGPLv3)**.

## Dual-Licensed ntop Components
On top of the core library, ntop has created additional components released under a **dual-license model**. The license that applies to these specific components depends directly on your project classification:

### 1. Not-for-Profit Projects
*   **Definition:** All projects where nDPI does **not** create direct revenue (e.g., a product built on top of nDPI) or indirect revenue (e.g., providing a service powered by nDPI).
*   **Licensing:** You can use the additional ntop dual-licensed components freely **without** purchasing a commercial license.

### 2. For-Profit Projects
*   **Definition:** Any project or commercial use case where nDPI is utilized to generate direct or indirect revenue.
*   **Options for Commercial Projects:**
    *   **LGPLv3 Only:** You may choose to use *only* the core LGPLv3 nDPI components.
    *   **Commercial License:** If you wish to use the extra dual-licensed ntop components within your business project, you must sign a **commercial license agreement** with ntop. Please mail license@ntop.org 

## How can I set the intended nDPI library use?
When you initialise the nDPI library you need to specify the library *intended use* in the `ndpi_init_detection_module()` API call used to initialise nDPI.

# Rationale Behind the Dual-License Model

### Fostering Sustainable Development
We introduced this dual-license model to **foster the long-term development of nDPI**. Deep Packet Inspection is a highly resource-intensive activity because network protocols change constantly. Keeping the library robust, secure, and up to date requires continuous engineering efforts.

### Protecting the Community from Exploitation
This change is specifically designed to avoid scenarios where commercial entities leverage our hard work to generate profits without returning any value to the project or the community. We believe it is unfair for businesses to build revenue-generating services or products directly on top of our open-source codebase while offering zero code contributions, financial support, or bug fixes back to the ecosystem.

### Reinvesting in the Future of nDPI
Funds collected from commercial nDPI licensing fees will be **directly reinvested** back into the library. We plan to use this revenue to sponsor active code development and fund other critical initiatives that directly improve the speed, protocol coverage, and cybersecurity capabilities of nDPI.

### Incentivizing Active Contributors
We deeply value the developers who help make nDPI better. To recognize their work, **ntop reserves the right to waive licensing fees for code contributors** who are actively developing and maintaining the library. If you actively give back to the project through high-quality code and extensions, we want to support you in return.

# Questions?
Please mail license@ntop.org for questions and comments.
