// Bare-metal C program for RISC-V 32-bit ISA
// Uses a structure, pointer, and a user-defined function with return value
// Flat memory model, PC starts at 0x00, no standard library

struct Point {
    int x;
    int y;
};

// User-defined function to return the sum of x and y coordinates
int sum_coordinates(struct Point *p) {
    return p->x + p->y;
}

void _start() {
    // Initialize structure at memory address 0x0
    struct Point p = {1, 2};
    struct Point *ptr = &p;
    
    // Modify structure via pointer
    ptr->x = 3;
    ptr->y = 4;
    
    // Call user-defined function and store result at 0x8
    int sum = sum_coordinates(ptr);
    *(volatile int *)0x8 = sum;  // Store sum (7) at 0x8 (mem[2])
    
    while (1) {}  // Infinite loop
}
