# Hardware-Assisted Instruction Set Randomization (ISR) on 32-bit RISC-V (Ibex) on Xilinx Kria KV260
[![RISC-V](https://img.shields.io/badge/ISA-RISC--V%20RV32IMC-blue.svg)](https://riscv.org/)
[![Target Board](https://img.shields.io/badge/FPGA-Xilinx%20Kria%20KV260-green.svg)](https://www.xilinx.com/products/som/kria/kv260-vision-starter-kit.html)
[![Core](https://img.shields.io/badge/Core-lowRISC%20Ibex-orange.svg)](https://github.com/lowRISC/ibex)
[![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey.svg)](LICENSE)
> **Bachelor of Engineering Internship & Capstone Project**  
> **Author:** Nguyen Nhat Quang (Student ID: 2212746)  
> **Institution:** Department of Electronics, Ho Chi Minh City University of Technology (HCMUT - VNU-HCM)  
> **Supervisor:** Dr. Truong Quang Vinh  
---
##  1. Project Overview & Motivation
Embedded systems and IoT edge devices are increasingly vulnerable to binary-level exploits, notably **Buffer Overflow**, **Code Injection**, and **Return-Oriented Programming (ROP)** attacks. These attacks exploit the static nature of standard Instruction Set Architectures (ISA).
This repository implements a **Hardware-Assisted Instruction Set Randomization (ISR)** defense integrated directly into the pipeline of the open-source **lowRISC Ibex RISC-V Core (RV32IMC)**, deployed and verified on the **AMD/Xilinx Kria KV260 Vision AI Starter Kit**.
###  Core Security Concept:
* **Pre-load Encryption (Software Toolchain):** The binary program is compiled, partitioned, and statically encrypted using a secret key before being loaded into memory.
* **On-the-Fly Decryption (Hardware Pipeline):** A lightweight combinational hardware decoder in the **Instruction Fetch (IF)** stage decrypts instructions with **Zero-cycle Latency**.
* **Active Defense (Attack Trapping):** Injected shellcode or code encrypted with an incorrect key fails to produce valid RISC-V opcodes, immediately triggering an **Illegal Instruction Exception (Trap)** and halting execution safely.
---
##  2. System Architecture
### 2.1. SoC-Level AXI Interconnect Topology
The system models an asymmetric dual-core architecture: the **Zynq UltraScale+ PS** acts as the host manager, and the **Ibex RISC-V Core** acts as the secure target processor, communicating over a high-throughput **AXI4 Full Interconnect**.
```mermaid
graph TD
    classDef master fill:#f9d0c4,stroke:#e05263,stroke-width:2px;
    classDef slave fill:#d4edda,stroke:#28a745,stroke-width:2px;
    classDef bus fill:#cce5ff,stroke:#0056b3,stroke-width:4px;
    subgraph AXI_MASTERS ["AXI Masters"]
        ZYNQ["Zynq UltraScale+ PS"]:::master
        JTAG["JTAG to AXI Master"]:::master
        IBEX["Ibex RISC-V Subsystem"]:::master
    end
    
    AXI_BUS{"AXI4 INTERCONNECT FABRIC"}:::bus
    
    subgraph AXI_SLAVES ["AXI Slaves"]
        BRAM[("True Dual-Port BRAM 64KB")]:::slave
        CTRL["AXI GPIO / Reset Control"]:::slave
    end
    ZYNQ <-->|"AXI Full"| AXI_BUS
    JTAG <-->|"AXI Full"| AXI_BUS
    IBEX <-->|"AXI Full"| AXI_BUS
    
    AXI_BUS <-->|"AXI Full"| BRAM
    AXI_BUS <-->|"AXI4-Lite"| CTRL
2.2. Ibex AXI Wrapper & ISR Microarchitecture
The Ibex core uses the Open Bus Interface (OBI). An AXI Wrapper translates OBI transactions into two AXI4-Full Master interfaces (m_axi_instr and m_axi_data). The ISR Hardware Decoder is strategically placed on the instruction fetch datapath before the Prefetch Buffer.


 3. Synthesis & Implementation Results (Post-Route on KV260)
The design was synthesized and implemented using AMD Xilinx Vivado 2023.1 targeting the Zynq UltraScale+ MPSoC (xck26-sfvc784-2LV-c).

Resource Utilization:
Resource	Baseline (Original Ibex)	Ibex-ISR (Proposed)	Overhead / Difference
LUT (Look-Up Table)	10,731	11,193	+462 (+4.3%)
FF (Flip-Flop)	10,677	13,436	+2,759 (due to System ILA Debug Core)
BRAM (Block RAM)	16	13.5	-2.5
DSP	1	1	0 (0%)
Timing & Power Summary:
Worst Negative Slack (WNS): +0.144 ns (Timing Met at 100 MHz).
Total On-Chip Power: 2.797 W (Baseline: 2.818 W).
Latency Overhead: 0 Clock Cycles (Combinational real-time XOR decoding).
 4. System Verification & Security Evaluation
The system was evaluated across 3 testing scenarios via Verilator Simulation and Physical FPGA Execution:

Test Group	Security Scenario	Encryption Key	Expected Behavior	Status
Group 1: Baseline	Unmodified CPU, No ISR	N/A	Normal execution of ALU math, Fibonacci, Checksum.	PASS ✅
Group 2: Golden Run	ISR Enabled, Valid Key	0xA1B2C3D4	Ciphertext in BRAM decoded transparently in real-time.	PASS ✅
Group 3: Attack Scenario	Code Injection / Wrong Key	0x11223344 or Plaintext	Invalid opcodes trigger Illegal Instruction Trap; CPU safely halted; DECERR captured by ILA.	PASS 🛡️
 5. Repository Directory Structure
text


├── docs/                        # Complete 45-page Project Report & Thesis docs
│   ├── Bao_Cao_Do_An_ISR.pdf
│   └── drawio/                  # Architecture vector files (.drawio)
├── kv260_deploy/                # FPGA deployment binaries for Linux on Kria
│   ├── ibex_wrapper.bit.bin
│   ├── ibex_wrapper.dtbo
│   └── shell.json
├── rtl/                         # Synthesizable SystemVerilog Source Codes
│   ├── ibex_isr_decoder.sv      # Lightweight XOR Hardware Decoder
│   ├── ibex_axi_wrapper.sv      # OBI to AXI4 Protocol Converter
│   └── ibex_if_stage.sv         # Modified Instruction Fetch stage
├── sw/                          # Software Toolchain & Test Cases
│   ├── isr_encoder.py           # Memory partition & encryption tool
│   └── test_programs/           # .vmem and source files
├── tb/                          # Unit Testbenches for Simulation
└── vivado/                      # Vivado TCL scripts for full project recreation
    └── scripts/
        ├── create_project.tcl
        └── load_bram.tcl
 6. Quick Start & Deployment Guide
Step 1: Encrypt Application Binary
Use the Python encoder to partition memory and encrypt the text segment:

bash


python3 sw/isr_encoder.py -i sw/test_programs/test_input.vmem -o isr_test_encoded.vmem -k A1B2C3D4
Step 2: Load Bitstream on Kria KV260 (via MobaXterm / Linux PS)
Transfer deployment files to KV260 and execute:

bash


sudo fpgautil -b kv260_deploy/ibex_wrapper.bit.bin -f Full
This command un-isolates the AXI fabric and initializes the PL clock domain.

Step 3: Hardware Control & Debugging (via Vivado Hardware Manager)
Open Vivado Hardware Manager and connect to the target board.
In Virtual I/O (VIO), set probe_out = 1 to hold the Ibex core in reset.
In Vivado Tcl Console, load the encrypted instructions directly to BRAM:
tcl


source vivado/scripts/load_bram.tcl
Arm the System ILA trigger, then toggle VIO probe_out = 0 to release reset.
Observe live AXI transactions and real-time instruction execution.
 7. References
[1] G. S. Kc et al., "Countering code-injection attacks with instruction-set randomization," ACM CCS, 2003.
[2] lowRISC, "Ibex RISC-V Core Reference Guide," lowRISC CIC, 2023.
[3] ARM Ltd., "AMBA AXI and ACE Protocol Specification," 2011.
[4] AMD Xilinx, "Kria KV260 Vision AI Starter Kit User Guide (UG1089)," 2022.
© 2026 Department of Electronics, Ho Chi Minh City University of Technology (HCMUT).
