package fuse_lut_pkg;
`include "caliptra_reg_defines.svh"
`include "caliptra_fuse_pkt.svh"

typedef struct packed {
  logic [31:0] mask;
  logic [31:0] source_address;
  logic [31:0] dest_address;
} fuse_lut_element_t;

parameter LUT_ENTRIES = 64;

`define CALIPTRA_WDT_CONFIG0_LOW  32'h000F_0000 
`define CALIPTRA_WDT_CONFIG1_LOW  32'h0000_0000 
`define CALIPTRA_WDT_CONFIG0_MED  32'h0000_0000 
`define CALIPTRA_WDT_CONFIG1_MED  32'h0000_000F 
`define CALIPTRA_WDT_CONFIG0_HIGH 32'h0000_0000 
`define CALIPTRA_WDT_CONFIG1_HIGH 32'h000F_0000 
`define CALIPTRA_WDT_CONFIG0_FULL 32'hFFFF_FFFF 
`define CALIPTRA_WDT_CONFIG1_FULL 32'hFFFF_FFFF 

endpackage

