# Instruction Queue with Scheduling Algorithms and Temporal Verification

This project implements a complete RTL architecture for an **Instruction Queue with dynamic scheduling**, **dependency analysis**, **resource binding**, and **formal temporal verification**. The design integrates a reservation-station–style instruction queue, a dependency DAG builder, and a scheduler that issues instructions based on readiness and functional-unit availability.

## 📌 Problem Statement

Implement an instruction queue with dynamic issue logic. Use list scheduling algorithms to prioritize instructions based on dependencies. Build a dependency Directed Acyclic Graph (DAG) for instructions in the queue using adjacency lists. Apply resource binding optimization for multiple functional units (ALU, MUL, DIV). Write CTL properties to verify that:
- Instructions issue in valid order  
- No resource conflicts occur  
- All RAW/WAR/WAW dependencies are respected  

Use topological sorting on the dependency graph to determine the valid issue order and apply model checking to ensure deadlock freedom.

## 📐 System Overview

The design consists of three RTL modules:

### **1. Instruction Queue (Reservation Station)**
- Holds up to 4 instructions  
- Parallel access to all entries  
- Out-of-order retirement  
- Reuse of freed slots in the same cycle  
- Exposes instruction fields and validity bits for DAG construction  

### **2. Dependency DAG Builder**
Constructs the following 4×4 adjacency matrices:
- **RAW (Read After Write)**  
- **WAR (Write After Read)**  
- **WAW (Write After Write)**  

Implements:
- Nearest-producer RAW detection  
- Forward-scan WAR/WAW detection  
- Ready-vector generation based on no incoming RAW edges  

### **3. Resource-Binding Scheduler**
- Priority-based list scheduling  
- Single issue per cycle (lower-index wins)  
- Multi-FU support (ALU, MUL, DIV)  
- Dynamic RAW matrix updates on instruction completion  
- FU busy counters model multi-cycle execution latency  

## 🔧 Functional Unit Mapping

| Opcode | Operation Type | FU | Latency |
|--------|----------------|----|---------|
| 00 | ALU Arithmetic | ALU | 2 cycles |
| 01 | ALU Logical | ALU | 2 cycles |
| 10 | Multiply | MUL | 3 cycles |
| 11 | Divide | DIV | 4 cycles |

## 📊 Scheduling Algorithm

The scheduler follows list scheduling with priority:

1. Compute dependency-ready instructions via RAW matrix  
2. Check resource availability  
3. Choose the highest-priority ready instruction  
4. Bind to a free functional unit  
5. Update dynamic RAW matrix when instructions retire  
6. Repeat until queue becomes empty  

This produces **in-order issue (when possible)** and **out-of-order completion** depending on FU latencies.

## 🧩 Topological Sorting

A valid issue sequence corresponds to a topological sort of the dependency DAG:

- RAW edges always point forward (from older to younger instruction)
- The scheduler effectively computes a topological order by selecting ready nodes with lowest index
- All issued instructions were verified to respect DAG ordering

## 🔒 Temporal Verification (CTL Properties)

### **1. Valid Issue Order**
```
AG(issue_valid → dependencies_satisfied)
```

### **2. No Resource Conflicts**
```
AG(no_FU_double_booking)
```

### **3. Dependency Respect**
```
AG(RAW[i][j] → AF(retire[i] before issue[j]))
```

### **4. Progress / Deadlock Freedom**
```
AG(nonempty_queue → AF(issue_valid))
```

All properties pass under simulation and formal analysis.

## 🧪 Testbench & Results

The system was tested with:
- Mixed dependency patterns  
- Pure chain dependencies  
- Complex multi-hazard RAW propagation  

Results show:
- Correct dependency detection  
- Proper FU binding  
- Correct issue order (topologically valid)  
- Out-of-order completion  
- No deadlocks in any configuration  

## 🚀 Future Enhancements

- Expand instruction window (8–32 entries)  
- Multi-issue per cycle  
- Memory-load/store dependency analysis  
- 32-bit/64-bit ISA support  
- Speculative execution and branch handling  
- Register renaming + Reorder Buffer (ROB)  
- FPGA implementation  


