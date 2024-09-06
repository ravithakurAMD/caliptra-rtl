/*
* Caliptra Fuse Distribtuion Machine (FDM)
* 
*/
module caliptra_fdm
  import fuse_lut_pkg::*;
#(
  parameter APB_ADDR_WIDTH = 32,
  parameter APB_DATA_WIDTH = 32,
  parameter APB_STRB_WIDTH = 4
  
) (
  input                              i_clk,
  input                              i_resetn,

  input                              i_cptra_ready_for_fuses,

  output                             o_cptra_fdm_error,

  //CPTRA WRAPPER -> FUSE APB
  output                             o_FUSE_apb_presetn,
  output                             o_FUSE_apb_psel,
  output                             o_FUSE_apb_penable,
  output                             o_FUSE_apb_pwrite,
  output [APB_ADDR_WIDTH-1:0]        o_FUSE_apb_paddr,
  output [APB_DATA_WIDTH-1:0]        o_FUSE_apb_pwdata,
  output [APB_STRB_WIDTH-1:0]        o_FUSE_apb_pstrb,
  input  [APB_DATA_WIDTH-1:0]        i_FUSE_apb_prdata,
  input                              i_FUSE_apb_pready,
  input                              i_FUSE_apb_pslverr,

  //CPTRA WRAPPER -> CPTRA APB
  output                             o_CPTRA_apb_psel,
  output                             o_CPTRA_apb_penable,
  output                             o_CPTRA_apb_pwrite,
  output [APB_ADDR_WIDTH-1:0]        o_CPTRA_apb_paddr,
  output [APB_DATA_WIDTH-1:0]        o_CPTRA_apb_pwdata,
  output [2:0]                       o_CPTRA_apb_pprot,
  output [APB_STRB_WIDTH-1:0]        o_CPTRA_apb_pstrb,
  input  [APB_DATA_WIDTH-1:0]        i_CPTRA_apb_prdata,
  input                              i_CPTRA_apb_pready,
  input                              i_CPTRA_apb_pslverr
);
  
  fuse_lut_element_t lut_data;
  
  wire                      apb_done;
  wire                      apb_error;
  wire [APB_DATA_WIDTH-1:0] apb_sm_rdata;

  enum logic [3:0] {
    ST_FDM_IDLE            = 4'b0000,
    ST_FDM_READ_LUT        = 4'b0001,
    ST_FDM_READ_FUSE       = 4'b0010,
    ST_FDM_SHIFT_DATA      = 4'b0011,
    ST_FDM_WRITE_CPTRA     = 4'b0100,
    ST_FDM_RD_WDT_CONFIG   = 4'b0101,
    ST_FDM_PROC_WDT_CONFIG = 4'b0110,
    ST_FDM_WR_WDT_CONFIG0  = 4'b0111,
    ST_FDM_WR_WDT_CONFIG1  = 4'b1000,
    ST_FDM_WR_DONE         = 4'b1001,  
    ST_FDM_DONE            = 4'b1010, 
    ST_FDM_ERROR           = 4'b1011  
  } fdm_state, fdm_state0q;
  
  reg [$clog2(LUT_ENTRIES)-1:0] lut_raddr0q,  lut_raddr;
  reg                           lut_readen0q, lut_readen;
  reg [APB_ADDR_WIDTH-1:0]      src_addr0q,   src_addr;
  reg [APB_ADDR_WIDTH-1:0]      dst_addr0q,   dst_addr;
  reg                           apb_op0q,     apb_op;
  reg                           apb_en0q,     apb_en;
  reg [31:0]                    mask0q,       mask;
  reg [APB_DATA_WIDTH-1:0]      apb_rdata0q,  apb_rdata;
  reg [APB_DATA_WIDTH-1:0]      apb_wdata0q,  apb_wdata;
  reg                           apb_resetn0q, apb_resetn;
  reg                           fdm_error0q,  fdm_error;

  always_ff @(posedge i_clk) begin
    if (~i_resetn) begin
      fdm_state0q  <= ST_FDM_IDLE;
      lut_raddr0q  <= {$clog2(LUT_ENTRIES){1'b0}};
      src_addr0q   <= {APB_ADDR_WIDTH{1'b0}};
      dst_addr0q   <= {APB_ADDR_WIDTH{1'b0}};
      mask0q       <= 32'b0;
      apb_op0q     <= 1'b0;
      apb_en0q     <= 1'b0;
      apb_rdata0q  <= {APB_DATA_WIDTH{1'b0}};
      apb_wdata0q  <= {APB_DATA_WIDTH{1'b0}};
      apb_resetn0q <= 1'b0;
      fdm_error0q  <= 1'b0;
    end else begin
      fdm_state0q  <= fdm_state;
      lut_raddr0q  <= lut_raddr;
      src_addr0q   <= src_addr;
      dst_addr0q   <= dst_addr;
      mask0q       <= mask;
      apb_op0q     <= apb_op;
      apb_en0q     <= apb_en;
      apb_rdata0q  <= apb_rdata;
      apb_wdata0q  <= apb_wdata;
      apb_resetn0q <= apb_resetn;
      fdm_error0q  <= fdm_error;
    end
  end

  always_comb begin
    fdm_state  = fdm_state0q;
    lut_raddr  = lut_raddr0q;
    lut_readen = 1'b0;
    src_addr   = src_addr0q;
    dst_addr   = dst_addr0q;
    mask       = mask0q;
    apb_op     = 1'b0;
    apb_en     = 1'b0;
    apb_rdata  = apb_rdata0q;
    apb_wdata  = apb_wdata0q;
    apb_resetn = apb_resetn0q;
    fdm_error  = 1'b0;

    unique case(fdm_state0q)
      ST_FDM_IDLE: begin
        if (i_cptra_ready_for_fuses) begin      //Caliptra is ready for fuses to be pushed. No need to wait for FUSE as APB PREADY will backpressure if not ready
          fdm_state  = ST_FDM_RD_WDT_CONFIG;
          src_addr   = `CALIPTRA_FPF_WDT;
          dst_addr   = `CLP_SOC_IFC_REG_CPTRA_WDT_CFG_0;
          mask       = `CALIPTRA_FPF_WDT_MASK;
          apb_resetn = 1'b1;                    //Release FUSE APB interface from reset
        end
      end
      ST_FDM_READ_LUT: begin
        if(&lut_data) begin                     //Check for LUT EOF to move into final tasks
          apb_en     = 1'b0;
          fdm_state  = ST_FDM_DONE;
          apb_resetn = 1'b0;                    //Done with FUSE APB, put back in reset
        end else begin                          //Valid data
          src_addr   = lut_data.source_address;
          dst_addr   = lut_data.dest_address;
          mask       = lut_data.mask;
          fdm_state  = ST_FDM_READ_FUSE;
          lut_raddr  = lut_raddr0q + 1'b1;      //Increment the LUT address
        end
      end
      ST_FDM_READ_FUSE: begin
        apb_op       = 1'b0;                    //0x0 = Read, 0x1 = Write 
        apb_en       = 1'b1;
        if (apb_done) begin
          if (apb_error) begin
            fdm_state  = ST_FDM_ERROR;
            apb_en     = 1'b0;                  //Stop APB machine
          end else if(&mask0q) begin            //Full DWORD data, go directly to write APB with no mask/shift
            fdm_state  = ST_FDM_WRITE_CPTRA;
            apb_en     = 1'b0;                  //Stop APB machine until we re-set the Operation in WRITE state.
            apb_wdata  = apb_sm_rdata;          //Write data as-is from APB read 
          end else begin
            fdm_state  = ST_FDM_SHIFT_DATA;     //MASK is not DWORD so we need to mask/shift read data from FUSE before writing to CPTRA.
            apb_en     = 1'b0;                  //Stop APB machine until we re-set the Operation in WRITE state.
            apb_rdata  = apb_sm_rdata & mask0q; //First MASK the read data from FUSE using the MASK from LUT.
          end
        end
      end
      ST_FDM_SHIFT_DATA: begin
        mask           = mask0q >> 32'b1;
        if(mask0q[0]) begin                     //We know we reached the end of the shift operation
          fdm_state    = ST_FDM_WRITE_CPTRA;
          apb_wdata    = apb_rdata0q;
        end else begin
          fdm_state    = ST_FDM_SHIFT_DATA;
          apb_rdata    = apb_rdata0q >> 32'b1;  //Shift down one-bit per clock
        end
      end
      ST_FDM_WRITE_CPTRA: begin
        apb_op         = 1'b1;
        apb_en         = 1'b1;
        if (apb_done) begin
          if (apb_error) begin
            fdm_state  = ST_FDM_ERROR;
            apb_en     = 1'b0;                  //Stop APB machine
          end else begin
            fdm_state  = ST_FDM_READ_LUT;
            apb_en     = 1'b0;                  //Stop APB machine as we go back to reading next LUT entry.
            lut_readen = 1'b1;                  //Read next LUT entry
          end
        end
      end
      ST_FDM_RD_WDT_CONFIG: begin               //Read the WDT CONFIG FUSE. This is a special FUSE that is only 2-bits and needs to be decoded.
        apb_op         = 1'b0;
        apb_en         = 1'b1;
        if (apb_done) begin
          if (apb_error) begin
            fdm_state  = ST_FDM_ERROR;
            apb_en     = 1'b0;                    //Stop APB machine
          end else begin
            fdm_state  = ST_FDM_PROC_WDT_CONFIG;
            apb_en     = 1'b0;
            apb_rdata  = apb_sm_rdata & mask0q;   //Apply 2-bit mask to data before shifting
          end
        end
      end
      ST_FDM_PROC_WDT_CONFIG: begin
        mask         = mask0q >> 32'b1;
        if (mask0q[0]) begin                    //Shift until mask hit LSB. 
          case(apb_rdata0q[1:0])                //Setup a APB write (dst_addr already set from above).
            2'b00:   apb_wdata = `CALIPTRA_WDT_CONFIG0_LOW;
            2'b01:   apb_wdata = `CALIPTRA_WDT_CONFIG0_MED;
            2'b10:   apb_wdata = `CALIPTRA_WDT_CONFIG0_HIGH;
            2'b11:   apb_wdata = `CALIPTRA_WDT_CONFIG0_FULL;
            default: apb_wdata = `CALIPTRA_WDT_CONFIG0_FULL;
          endcase
          fdm_state  = ST_FDM_WR_WDT_CONFIG0;
        end else begin
          fdm_state  = ST_FDM_PROC_WDT_CONFIG;
          apb_rdata  = apb_rdata0q >> 32'b1;
        end
      end
      ST_FDM_WR_WDT_CONFIG0: begin
        apb_op         = 1'b1;
        apb_en         = 1'b1;
        if (apb_done) begin
          if (apb_error) begin
            fdm_state  = ST_FDM_ERROR;
            apb_en     = 1'b0;                    //Stop APB machine
          end else begin
            fdm_state  = ST_FDM_WR_WDT_CONFIG1;
            apb_en     = 1'b0;
            dst_addr   = `CLP_SOC_IFC_REG_CPTRA_WDT_CFG_1;
            case(apb_rdata0q[1:0])
              2'b00:   apb_wdata = `CALIPTRA_WDT_CONFIG1_LOW;
              2'b01:   apb_wdata = `CALIPTRA_WDT_CONFIG1_MED;
              2'b10:   apb_wdata = `CALIPTRA_WDT_CONFIG1_HIGH;
              2'b11:   apb_wdata = `CALIPTRA_WDT_CONFIG1_FULL;
              default: apb_wdata = `CALIPTRA_WDT_CONFIG1_FULL;
            endcase
          end
        end
      end
      ST_FDM_WR_WDT_CONFIG1: begin
        apb_op         = 1'b1;
        apb_en         = 1'b1;
        if (apb_done) begin
          if (apb_error) begin
            fdm_state  = ST_FDM_ERROR;
            apb_en     = 1'b0;                    //Stop APB machine
          end else begin
            apb_en     = 1'b0;
            fdm_state  = ST_FDM_READ_LUT;
            lut_readen = 1'b1;                    //Trigger first read from LUT. LUT data is pipelined and will be available in the next state. 
          end
        end
      end
      ST_FDM_DONE: begin
        //Terminal State! 
      end
      ST_FDM_ERROR: begin
        //Terminal State! 
        fdm_error  = 1'b1;
      end
      default: begin end
    endcase
  end

  caliptra_fdm_apb u_caliptra_fdm_apb (
    .i_clk               (i_clk),
    .i_resetn            (i_resetn),
    .i_apb_en            (apb_en),
    .i_apb_op            (apb_op0q),
    .i_src_addr          (src_addr0q),
    .i_dst_addr          (dst_addr0q),
    .o_apb_error         (apb_error),
    .o_apb_done          (apb_done),
    .o_apb_sm_rdata      (apb_sm_rdata),
    .i_apb_sm_wdata      (apb_wdata0q),
    .o_FUSE_apb_psel     (o_FUSE_apb_psel),
    .o_FUSE_apb_penable  (o_FUSE_apb_penable),
    .o_FUSE_apb_pwrite   (o_FUSE_apb_pwrite),
    .o_FUSE_apb_paddr    (o_FUSE_apb_paddr),
    .o_FUSE_apb_pwdata   (o_FUSE_apb_pwdata),
    .o_FUSE_apb_pprot    (),
    .o_FUSE_apb_pstrb    (o_FUSE_apb_pstrb),
    .i_FUSE_apb_prdata   (i_FUSE_apb_prdata),
    .i_FUSE_apb_pready   (i_FUSE_apb_pready),
    .i_FUSE_apb_pslverr  (i_FUSE_apb_pslverr),
    .o_CPTRA_apb_psel    (o_CPTRA_apb_psel),
    .o_CPTRA_apb_penable (o_CPTRA_apb_penable),
    .o_CPTRA_apb_pwrite  (o_CPTRA_apb_pwrite),
    .o_CPTRA_apb_paddr   (o_CPTRA_apb_paddr),
    .o_CPTRA_apb_pwdata  (o_CPTRA_apb_pwdata),
    .o_CPTRA_apb_pprot   (o_CPTRA_apb_pprot),
    .o_CPTRA_apb_pstrb   (o_CPTRA_apb_pstrb),
    .i_CPTRA_apb_prdata  (i_CPTRA_apb_prdata),
    .i_CPTRA_apb_pready  (i_CPTRA_apb_pready),
    .i_CPTRA_apb_pslverr (i_CPTRA_apb_pslverr)
  );

  caliptra_fdm_lut_fetch u_caliptra_fdm_lut_fetch (
    .i_clk    (i_clk),
    .i_readen (lut_readen),
    .i_raddr  (lut_raddr0q),
    .o_rdata  (lut_data)
  );

  assign o_FUSE_apb_presetn = apb_resetn0q;
  assign o_cptra_fdm_error  = fdm_error0q;

endmodule

