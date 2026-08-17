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
### Quick Start & Deployment Guide
Step 1: Encrypt Application Binary
Use the Python encoder to partition memory and encrypt the text segment:
```text
python3 sw/isr_encoder.py -i sw/test_programs/test_input.vmem -o isr_test_encoded.vmem -k A1B2C3D4
```
Step 2: Load Bitstream on Kria KV260 (via MobaXterm / Linux PS)
Transfer deployment files to KV260 and execute:
```text
sudo fpgautil -b kv260_deploy/ibex_wrapper.bit.bin -f Full
```
This command un-isolates the AXI fabric and initializes the PL clock domain.

Step 3: Hardware Control & Debugging (via Vivado Hardware Manager)
1. Open Vivado Hardware Manager and connect to the target board.
2. In Virtual I/O (VIO), set probe_out = 1 to hold the Ibex core in reset.
3. In Vivado Tcl Console, load the encrypted instructions directly to BRAM:
```text
source vivado/scripts/load_bram.tcl
```
4. Arm the System ILA trigger, then toggle VIO probe_out = 0 to release reset.
5. Observe live AXI transactions and real-time instruction execution.
© 2026 Department of Electronics, Ho Chi Minh City University of Technology (HCMUT).
