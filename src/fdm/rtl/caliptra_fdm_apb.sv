module caliptra_fdm_apb #(
  parameter APB_ADDR_WIDTH = 32,
  parameter APB_DATA_WIDTH = 32,
  parameter APB_STRB_WIDTH = 4
  
) (
  input                              i_clk,
  input                              i_resetn,

  input                              i_apb_en,
  input                              i_apb_op,
  input  [APB_ADDR_WIDTH-1:0]        i_src_addr,
  input  [APB_ADDR_WIDTH-1:0]        i_dst_addr,
  output                             o_apb_error,
  output                             o_apb_done,
  output [APB_DATA_WIDTH-1:0]        o_apb_sm_rdata,
  input  [APB_DATA_WIDTH-1:0]        i_apb_sm_wdata,

  //CPTRA WRAPPER -> FUSE APB
  output                             o_FUSE_apb_psel,
  output                             o_FUSE_apb_penable,
  output                             o_FUSE_apb_pwrite,
  output [APB_ADDR_WIDTH-1:0]        o_FUSE_apb_paddr,
  output [APB_DATA_WIDTH-1:0]        o_FUSE_apb_pwdata,
  output [2:0]                       o_FUSE_apb_pprot,
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
  
 
  enum logic [1:0] {
    ST_APB_IDLE         = 2'b00,
    ST_APB_SETUP_PHASE  = 2'b01,
    ST_APB_ACCESS_PHASE = 2'b10
  } apb_state, apb_state0q;
  
  reg [APB_ADDR_WIDTH-1:0] apb_paddr0q,   apb_paddr;
  reg                      apb_psel0q,    apb_psel;
  reg                      apb_penable0q, apb_penable;
  reg [APB_DATA_WIDTH-1:0] apb_pwdata0q,  apb_pwdata;
  reg                      apb_done0q,    apb_done;
  reg                      apb_error0q,   apb_error;
  reg                      apb_pwrite0q,  apb_pwrite;
  reg [APB_DATA_WIDTH-1:0] fuse_data0q,   fuse_data;
  wire                     bus_ready;

  always_ff @(posedge i_clk) begin
    if (~i_resetn) begin
      apb_state0q   <= ST_APB_IDLE;
      apb_paddr0q   <= {APB_ADDR_WIDTH{1'b0}};
      apb_psel0q    <= 1'b0;
      apb_penable0q <= 1'b0;
      apb_pwdata0q  <= {APB_DATA_WIDTH{1'b0}};
      apb_done0q    <= 1'b0;
      apb_error0q   <= 1'b0;
      fuse_data0q   <= {APB_DATA_WIDTH{1'b0}};
    end else begin
      apb_state0q   <= apb_state;
      apb_paddr0q   <= apb_paddr;
      apb_psel0q    <= apb_psel;
      apb_penable0q <= apb_penable;
      apb_pwdata0q  <= apb_pwdata;
      apb_done0q    <= apb_done;
      apb_error0q   <= apb_error;
      fuse_data0q   <= fuse_data;
    end
  end

  always_comb begin
    apb_paddr   = {APB_ADDR_WIDTH{1'b0}};
    apb_psel    = 1'b0;
    apb_penable = 1'b0;
    apb_pwrite  = 1'b0;
    apb_pwdata  = {APB_DATA_WIDTH{1'b0}};
    apb_state   = apb_state0q;
    apb_done    = 1'b0;
    apb_error   = 1'b0;
    fuse_data   = {APB_DATA_WIDTH{1'b0}};

    unique case (apb_state0q)
      ST_APB_IDLE: begin
        if (i_apb_en) begin
          apb_state = ST_APB_SETUP_PHASE;
        end
      end
      ST_APB_SETUP_PHASE: begin
        apb_paddr   = i_apb_op ? i_dst_addr : i_src_addr; //Depending on RD/WR operation from master FSM, select source/dest address
        apb_psel    = 1'b1;
        apb_pwrite  = i_apb_op;
        apb_pwdata  = i_apb_op ? i_apb_sm_wdata : {APB_DATA_WIDTH{1'b0}};
        apb_state   = ST_APB_ACCESS_PHASE;
      end
      ST_APB_ACCESS_PHASE: begin
        apb_paddr   = i_apb_op ? i_dst_addr : i_src_addr; //Depending on RD/WR operation from master FSM, select source/dest address
        apb_psel    = 1'b1;
        apb_pwrite  = i_apb_op;
        apb_pwdata  = i_apb_op ? i_apb_sm_wdata : {APB_DATA_WIDTH{1'b0}};
        apb_penable = 1'b1;     
        if (bus_ready) begin
          apb_state = ST_APB_IDLE;
          apb_done  = 1'b1;
          fuse_data = i_FUSE_apb_prdata;
          apb_error = i_apb_op ? i_CPTRA_apb_pslverr : i_FUSE_apb_pslverr;
        end
      end
      default: begin end
    endcase
  end
  
  assign o_apb_error    = apb_error0q;
  assign o_apb_done     = apb_done0q;
  assign o_apb_sm_rdata = fuse_data0q;
  
  assign bus_ready = i_apb_op ? i_CPTRA_apb_pready : i_FUSE_apb_pready;
  
  assign o_FUSE_apb_paddr    = i_apb_op ? {APB_ADDR_WIDTH{1'b0}} : apb_paddr;    //Grab from APB machine if read operation
  assign o_FUSE_apb_psel     = i_apb_op ? 1'b0                   : apb_psel;     //Grab from APB machine if read operation
  assign o_FUSE_apb_penable  = i_apb_op ? 1'b0                   : apb_penable;  //Grab from APB machine if read operation
  assign o_FUSE_apb_pwrite   = 1'b0;                                             //Always read from FUSE
  assign o_FUSE_apb_pwdata   = {APB_DATA_WIDTH{1'b0}};                           //Always read from FUSE
  assign o_FUSE_apb_pprot    = 3'b0;                                             //Unused
  assign o_FUSE_apb_pstrb    = {APB_STRB_WIDTH{1'b0}};                           //Always read from FUSE
  
  assign o_CPTRA_apb_paddr   = i_apb_op ? apb_paddr   : {APB_ADDR_WIDTH{1'b0}};  //Grab from APB machine if write operation
  assign o_CPTRA_apb_psel    = i_apb_op ? apb_psel    : 1'b0;                    //Grab from APB machine if write operation
  assign o_CPTRA_apb_penable = i_apb_op ? apb_penable : 1'b0;                    //Grab from APB machine if write operation
  assign o_CPTRA_apb_pwrite  = 1'b1;                                             //Always write to CPTRA
  assign o_CPTRA_apb_pwdata  = apb_pwdata;                                       //Write the data we read from FUSE
  assign o_CPTRA_apb_pprot   = 3'b0;                                             //Unused
  assign o_CPTRA_apb_pstrb   = {APB_STRB_WIDTH{1'b1}};                           //Always write DWORD 

endmodule
