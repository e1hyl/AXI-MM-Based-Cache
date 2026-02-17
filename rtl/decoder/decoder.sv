`timescale 1ns / 1ps

module decoder (
    input  logic read_or_write,   // 0=READ, 1 = WRITE
    input  logic [127:0]  result_arb,

    output logic [31:0]  addr,
    output logic [3:0]   id,
    output logic [1:0]   burst,
    output logic [2:0]   size,
    output logic [7:0]   len,

    output logic [63:0]  wdata,
    output logic [7:0]   wstrb,

    output logic [21:0]  tag,
    output logic [6:0]   index,
    output logic [2:0]   offset
);