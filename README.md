# 5x5 & 4x4 2D Mesh Network-on-Chip (NoC) Design & Verification Suite

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Simulation](https://img.shields.io/badge/Simulator-Icarus%20Verilog-green.svg)](http://iverilog.icarus.com/)
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)
[![Verification](https://img.shields.io/badge/Verification-100%25%20PASS-success.svg)](#verification--testbench-suite)

A high-performance, modular, and academically rigorous **SystemVerilog implementation of a 2D Mesh Network-on-Chip (NoC)**. Designed for modern multi-core SoC architectures, AI accelerators, and high-throughput parallel computing platforms.

This repository features:
- **5-Port 2D Mesh Router (`mesh_router_5x5.sv`)** with elastic buffer input slices, dimension-order XY routing, and round-robin output port arbitration.
- **5x5 Grid Topology (`mesh_5x5.sv`)** supporting 25 processing nodes with 3-bit coordinate addressing.
- **4x4 Grid Topology (`mesh_4x4.sv`)** supporting 16 processing nodes with 2-bit coordinate addressing.
- **8 Comprehensive Verification Testbenches** covering unit router logic, directed corner-to-corner transfers, all-to-all pairs, heavy traffic backpressure, random injection, and a **20,000-packet stress test**.

---

## Table of Contents
1. [Executive Summary & Motivation](#executive-summary--motivation)
2. [Architectural Overview & Specifications](#architectural-overview--specifications)
3. [Core Mechanism & Theory of Operation](#core-mechanism--theory-of-operation)
   - [1. Elastic Buffer & Handshake Protocol](#1-elastic-buffer--handshake-protocol)
   - [2. Dimension-Order XY Routing Algorithm](#2-dimension-order-xy-routing-algorithm)
   - [3. Round-Robin Output Arbitration](#3-round-robin-output-arbitration)
   - [4. Deadlock-Free Proof (Turn Model Analysis)](#4-deadlock-free-proof-turn-model-analysis)
4. [Comparative Analysis (Advantages & Disadvantages)](#comparative-analysis-advantages--disadvantages)
5. [Verification & Testbench Suite](#verification--testbench-suite)
6. [How to Use & Quickstart Guide](#how-to-use--quickstart-guide)
7. [Repository Structure](#repository-structure)
8. [Academic References & Citation](#academic-references--citation)

---

## Executive Summary & Motivation

### Why Move from Shared Buses / Crossbars to Network-on-Chip (NoC)?

As Semiconductor Technology scales into multi-core and heterogeneous SoC designs (containing dozens to hundreds of CPU cores, GPUs, TPUs, and memory controllers), traditional interconnect structures face severe physical and microarchitectural bottlenecks:

| Architecture Metric | Shared Bus (e.g., AMBA AHB) | Crossbar Matrix (e.g., AXI Interconnect) | 2D Mesh Network-on-Chip (NoC) |
| :--- | :--- | :--- | :--- |
| **Scalability** | Non-scalable ($O(1)$ concurrent transfer) | Poor ($O(N^2)$ crossbar complexity) | Highly Scalable ($O(N)$ area, $O(\sqrt{N})$ bisection) |
| **Wire Delay & Capacitance** | High global wire capacitance & loading | High layout congestion & long wire runs | Short, localized point-to-point links |
| **Bandwidth** | Shared single bandwidth pool | High, but limited by routing matrix scaling | Multi-GB/s parallel throughput across mesh |
| **Modularity & P&R** | Hard to place & route at scale | Exponential layout degradation beyond 16 nodes | Grid-based modular layout (tiling friendly) |

**Network-on-Chip (NoC)** solves these problems by replacing long resistive-capacitive global wires with a **packet-switched micro-network** using short localized links and router nodes.

---

## Architectural Overview & Specifications

### 2D Mesh Top-Level Topology

In a 2D Mesh topology, processing elements (cores, memory interfaces, DMA engines) are placed on a regular Cartesian grid. Each node $(X, Y)$ is connected to its cardinal neighbors (**East, West, North, South**) and its **Local** processing core.

```
       +-------+     +-------+     +-------+     +-------+     +-------+
       | (0,4) |=====| (1,4) |=====| (2,4) |=====| (3,4) |=====| (4,4) |
       +-------+     +-------+     +-------+     +-------+     +-------+
           ||            ||            ||            ||            ||   
       +-------+     +-------+     +-------+     +-------+     +-------+
       | (0,3) |=====| (1,3) |=====| (2,3) |=====| (3,3) |=====| (4,3) |
       +-------+     +-------+     +-------+     +-------+     +-------+
           ||            ||            ||            ||            ||   
       +-------+     +-------+     +-------+     +-------+     +-------+
       | (0,2) |=====| (1,2) |=====| (2,2) |=====| (3,2) |=====| (4,2) |
       +-------+     +-------+     +-------+     +-------+     +-------+
           ||            ||            ||            ||            ||   
       +-------+     +-------+     +-------+     +-------+     +-------+
       | (0,1) |=====| (1,1) |=====| (2,1) |=====| (3,1) |=====| (4,1) |
       +-------+     +-------+     +-------+     +-------+     +-------+
           ||            ||            ||            ||            ||   
       +-------+     +-------+     +-------+     +-------+     +-------+
       | (0,0) |=====| (1,0) |=====| (2,0) |=====| (3,0) |=====| (4,0) |
       +-------+     +-------+     +-------+     +-------+     +-------+
```

### 5-Port Router Node Structure

Each router node (`mesh_router_5x5.sv`) contains 5 bidirectional ports:
- **Port 0: LOCAL** (Interface to local PE / Core)
- **Port 1: EAST** (Interface to node at $X+1, Y$)
- **Port 2: WEST** (Interface to node at $X-1, Y$)
- **Port 3: NORTH** (Interface to node at $X, Y+1$)
- **Port 4: SOUTH** (Interface to node at $X, Y-1$)

```
                        +-----------------------------------+
                        |             NORTH (Port 3)        |
                        |          in_vld/rdy/data [3]      |
                        |                   ||              |
                        |                   \/              |
   WEST (Port 2) ======>| [Elastic Buf] -> [XY Routing]     |======> EAST (Port 1)
 in_vld/rdy/data [2]    | [Elastic Buf] -> [Crossbar Mux]   |      out_vld/rdy/data [1]
                        | [Elastic Buf] -> [RR Arbiter]     |
                        |                   /\              |
                        |                   ||              |
                        |             SOUTH (Port 4)        |
                        +-----------------------------------+
                                        ||  /\
                                        \/  ||
                                    LOCAL (Port 0)
                                    (Core / Processor)
```

---

## Core Mechanism & Theory of Operation

### 1. Elastic Buffer & Handshake Protocol

Each router input port features a **1-entry elastic buffer (register slice)**.
- **Decoupling**: The elastic buffer isolates the upstream handshake (`in_vld` / `in_rdy`) from downstream routing decisions.
- **Handshake Condition**: Data transfer occurs on `posedge clk` when both `vld` and `rdy` are HIGH ($VLD \wedge RDY = 1$).
- **Bubble-Free Back-to-Back Flow**: The input ready signal is computed as:
  $$\text{in\_rdy}[i] = \sim \text{buf\_vld}[i] \; \lor \; \text{release}[i]$$
  This 1-cycle lookahead allows a new incoming packet to be stored in the exact same cycle the current packet is evicted, maintaining **100% throughput without bubble cycles**.

### 2. Dimension-Order XY Routing Algorithm

Routing is strictly deterministic **Dimension-Order Routing (X-first, then Y-second)**:
1. Compare target coordinate $X_{dest}$ with current node coordinate $X_{curr}$:
   - If $X_{dest} > X_{curr} \Rightarrow$ Route **EAST** (Port 1).
   - If $X_{dest} < X_{curr} \Rightarrow$ Route **WEST** (Port 2).
2. If $X_{dest} == X_{curr}$, compare $Y_{dest}$ with $Y_{curr}$:
   - If $Y_{dest} > Y_{curr} \Rightarrow$ Route **NORTH** (Port 3).
   - If $Y_{dest} < Y_{curr} \Rightarrow$ Route **SOUTH** (Port 4).
3. If $X_{dest} == X_{curr}$ and $Y_{dest} == Y_{curr} \Rightarrow$ Route **LOCAL** (Port 0).

#### Packet Format

- **4x4 Mesh (`mesh_4x4.sv`)**:
  - `[7:6]`: Destination X Coordinate ($0..3$)
  - `[5:4]`: Destination Y Coordinate ($0..3$)
  - `[3:0]`: Packet Data Payload

- **5x5 Mesh (`mesh_5x5.sv`)**:
  - `[7:5]`: Destination X Coordinate ($0..4$)
  - `[4:2]`: Destination Y Coordinate ($0..4$)
  - `[1:0]`: Packet Data Payload

### 3. Round-Robin Output Arbitration

When multiple input ports request the same output port simultaneously, a **Round-Robin Arbiter** per output port resolves contention:
- **Priority Pointer**: Maintains dynamic round-robin priority index $\text{ptr}_j \in [0..4]$ for output port $j$.
- **Fairness Guarantee**: No input port can be starved, preventing livelock under heavy traffic congestion.
- **Grant Matrix**: Computes grant vector $g_j[4:0]$ based on active input requests and current pointer state.

### 4. Deadlock-Free Proof (Turn Model Analysis)

In Network-on-Chip design, deadlocks occur when a set of packets form a circular wait dependency graph along network channels.

**Theorem**: *The proposed XY routing algorithm is strictly deadlock-free.*

**Proof**:
Under the turn model classification for 2D mesh networks, there are 8 possible turns between cardinal directions:
- $E \to N, E \to S, W \to N, W \to S$ (Allowed in adaptive routing)
- $N \to E, N \to W, S \to E, S \to W$

Because XY routing forces packets to completely traverse the X dimension before making any turn into the Y dimension:
1. **Forbidden Turns**: $N \to E$, $N \to W$, $S \to E$, $S \to W$ are **strictly prohibited** by the routing logic.
2. **Channel Dependency Graph (CDG)**: Eliminating these 4 turns breaks all cycles in the CDG.
3. **Conclusion**: Since the CDG is a Directed Acyclic Graph (DAG), the network is guaranteed to be **deadlock-free** without requiring virtual channels.

---

## Comparative Analysis (Advantages & Disadvantages)

### Advantages

1. **High Scalable Bandwidth**: Spatial frequency reuse across all grid links allows $N$ concurrent packet transmissions.
2. **Predictable & Low Latency**: Short, constant wire length between adjacent routers eliminates long global RC wire delays.
3. **Deadlock-Free by Construction**: Dimension-order XY routing guarantees 0 deadlocks without the overhead of virtual channel management.
4. **Elastic Backpressure**: Handshake flow control guarantees 0 packet loss due to buffer overrun under congestion.
5. **Professor & Classroom Friendly**: Clean, structured SystemVerilog code, highly readable synthesized multiplexers, and exhaustive test coverage.

### Disadvantages

1. **Hop-Dependent Latency**: Latency scales linearly with Manhattan Distance ($d = |X_{dst}-X_{src}| + |Y_{dst}-Y_{src}|$).
2. **Boundary Bandwidth Constraint**: Edge nodes lack wrap-around links (unlike Torus topologies), creating potential bisection bandwidth bottlenecks near center nodes.
3. **Non-Adaptive to Local Hotspots**: Deterministic XY routing cannot dynamically route around localized link congestion.

---

## Verification & Testbench Suite

The codebase includes an exhaustive **8-testbench suite** validated using Icarus Verilog (`iverilog`) and GTKWave.

| Testbench File | Target Module | Scope & Description | Status |
| :--- | :--- | :--- | :---: |
| [`tb_router.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_router.sv) | `mesh_router_5x5.sv` | Single router unit test across all 5 ports (Local, East, West, North, South) | **PASS** |
| [`tb_mesh_directed.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_directed.sv) | `mesh_4x4.sv` | Corner-to-corner directed routing in 4x4 grid | **PASS** |
| [`tb_mesh_directed_16x16.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_directed_16x16.sv) | `mesh_4x4.sv` | **Exhaustive 256-pair test** (Every node $i \to j$ for all $16 \times 16$ pairs) | **PASS** |
| [`tb_mesh_single.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_single.sv) | `mesh_4x4.sv` | Single destination congestion & back-to-back stream stress | **PASS** |
| [`tb_mesh_backpressure.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_backpressure.sv) | `mesh_4x4.sv` | Downstream stall injection & destination release dynamics | **PASS** |
| [`tb_mesh_random.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_random.sv) | `mesh_4x4.sv` | Random traffic pattern with randomized backpressure stalls | **PASS** |
| [`tb_mesh_large.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_large.sv) | `mesh_4x4.sv` | **Massive Stress Test**: 20,000 randomized packets across the mesh | **PASS** |
| [`tb_mesh_5x5.sv`](file:///c:/Users/gowsh/Downloads/TestBenches-20260601T021019Z-3-001/TestBenches/tb_mesh_5x5.sv) | `mesh_5x5.sv` | 5x5 Grid topology validation (25 nodes, corner-to-corner & center transfers) | **PASS** |

---

## How to Use & Quickstart Guide

### Prerequisites

- **Icarus Verilog** (`iverilog` v11.0+)
- **GTKWave** (Optional, for waveform inspection)
- **PowerShell** (Windows) or **Bash** (Linux / macOS)

### Running All Testbenches (Automated Script)

To execute the entire verification suite automatically:

```powershell
# Windows PowerShell
.\run_all.ps1
```

Expected Output:
```text
======================================================================
                           SUMMARY OF RESULTS                         
======================================================================

Testbench              Compile SimResult LogFile                   
---------              ------- --------- -------                   
tb_router              OK      PASS      tb_router.log             
tb_mesh_directed       OK      PASS      tb_mesh_directed.log      
tb_mesh_directed_16x16 OK      PASS      tb_mesh_directed_16x16.log
tb_mesh_single         OK      PASS      tb_mesh_single.log        
tb_mesh_backpressure   OK      PASS      tb_mesh_backpressure.log  
tb_mesh_random         OK      PASS      tb_mesh_random.log        
tb_mesh_large          OK      PASS      tb_mesh_large.log         
tb_mesh_5x5            OK      PASS      tb_mesh_5x5.log           
```

### Manual Compilation & Simulation (Individual Testbenches)

To compile and simulate a specific testbench (e.g., 5x5 Mesh):

```bash
# 1. Compile with Icarus Verilog (IEEE 1800-2012 SystemVerilog standard)
iverilog -g2012 -o tb_mesh_5x5.vvp tb_mesh_5x5.sv mesh_5x5.sv mesh_router_5x5.sv

# 2. Execute simulation
vvp tb_mesh_5x5.vvp

# 3. View Waveforms in GTKWave
gtkwave mesh_5x5.vcd
```

---

## Repository Structure

```text
mesh-5x5-noc-design/
├── mesh_router_5x5.sv           # Core 5-Port Router Unit (Elastic Buf, XY Route, RR Arb)
├── mesh_5x5.sv                  # 5x5 2D Mesh NoC Top Level (25 Nodes)
├── mesh_4x4.sv                  # 4x4 2D Mesh NoC Top Level (16 Nodes)
├── tb_router.sv                 # Unit Testbench for 5-port Router
├── tb_mesh_5x5.sv               # Directed Testbench for 5x5 Mesh Top Level
├── tb_mesh_directed.sv          # Corner-to-corner Testbench for 4x4 Mesh
├── tb_mesh_directed_16x16.sv    # Exhaustive 256-pair Testbench for 4x4 Mesh
├── tb_mesh_single.sv            # Congestion & Single Destination Testbench
├── tb_mesh_backpressure.sv      # Backpressure & Stall Testbench
├── tb_mesh_random.sv            # Random Traffic Testbench
├── tb_mesh_large.sv             # 20,000 Packet Stress Testbench
├── run_all.ps1                  # PowerShell Test Automation Runner
├── .gitignore                   # Excludes binaries, waveforms (*.vcd), and logs
└── README.md                    # Comprehensive Project Documentation
```

---

## Academic References & Citation

If you use this Network-on-Chip design in academic coursework, lab reports, or research publications, please consider referencing standard NoC literature:

1. **Dally, W. J., & Towles, B. P.** (2004). *Principles and Practices of Interconnection Networks*. Morgan Kaufmann.
2. **Benini, L., & De Micheli, G.** (2002). Networks on chips: A new SoC paradigm. *IEEE Computer*, 35(1), 70-78.
3. **Jerger, N. E., Peh, L. S., & Lipasti, M.** (2017). *On-Chip Networks*. Synthesis Lectures on Computer Architecture, Morgan & Claypool.

---

*Designed & Maintained for Hardware Engineering & Multi-Core System Design Education.*
