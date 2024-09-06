module caliptra_apb_arb 
#(
  parameter APB_ADDR_WIDTH = 32,
  parameter APB_DATA_WIDTH = 32,
  parameter APB_STRB_WIDTH = 4
  
) (

  input                       i_clk,
  input                       i_resetn,

  input  [APB_ADDR_WIDTH-1:0] i_apb0_paddr,
  input  [2:0]                i_apb0_pprot,
  input                       i_apb0_psel,
  input                       i_apb0_penable,
  input                       i_apb0_pwrite,
  input  [APB_DATA_WIDTH-1:0] i_apb0_pwdata,
  input  [APB_STRB_WIDTH-1:0] i_apb0_pstrb,
  input  [31:0]               i_apb0_pauser, 
  output                      o_apb0_pready,
  output                      o_apb0_pslverr,
  output [APB_DATA_WIDTH-1:0] o_apb0_prdata,
  
  input  [APB_ADDR_WIDTH-1:0] i_apb1_paddr,
  input  [2:0]                i_apb1_pprot,
  input                       i_apb1_psel,
  input                       i_apb1_penable,
  input                       i_apb1_pwrite,
  input  [APB_DATA_WIDTH-1:0] i_apb1_pwdata,
  input  [APB_STRB_WIDTH-1:0] i_apb1_pstrb,
  input  [31:0]               i_apb1_pauser, 
  output                      o_apb1_pready,
  output                      o_apb1_pslverr,
  output [APB_DATA_WIDTH-1:0] o_apb1_prdata,
  
  output [APB_ADDR_WIDTH-1:0] o_apb_paddr,
  output [2:0]                o_apb_pprot,
  output                      o_apb_psel,
  output                      o_apb_penable,
  output                      o_apb_pwrite,
  output [APB_DATA_WIDTH-1:0] o_apb_pwdata,
  output [APB_STRB_WIDTH-1:0] o_apb_pstrb,
  output [31:0]               o_apb_pauser, 
  input                       i_apb_pready,
  input                       i_apb_pslverr,
  input  [APB_DATA_WIDTH-1:0] i_apb_prdata
  
);
   
  enum logic [2:0] {
    ST_IDLE        = 3'b000,
    ST_APB0_SETUP  = 3'b001,
    ST_APB0_ACCESS = 3'b010,
    ST_APB1_SETUP  = 3'b011,
    ST_APB1_ACCESS = 3'b100
  } state, state0q;
  
  reg [1:0] grant0q,      grant;
  reg       apb0_psel,    apb0_psel0q;
  reg       apb1_psel,    apb1_psel0q;
  reg       apb0_penable, apb0_penable0q;
  reg       apb1_penable, apb1_penable0q;
  reg       apb0_pready,  apb0_pready0q;
  reg       apb1_pready,  apb1_pready0q;

  always_ff @(posedge i_clk) begin
    if (~i_resetn) begin
      state0q        <= ST_IDLE;
      grant0q        <= 2'b0;
      apb0_psel0q    <= 1'b0; 
      apb1_psel0q    <= 1'b0;
      apb0_penable0q <= 1'b0;
      apb1_penable0q <= 1'b0;
      apb0_pready0q  <= 1'b0;
      apb1_pready0q  <= 1'b0;
    end else begin
      state0q        <= state;
      grant0q        <= grant;
      apb0_psel0q    <= apb0_psel;
      apb1_psel0q    <= apb1_psel;
      apb0_penable0q <= apb0_penable;
      apb1_penable0q <= apb1_penable;
      apb0_pready0q  <= apb0_pready;
      apb1_pready0q  <= apb1_pready;
    end
  end

  always_comb begin
    grant         = 2'b00;
    state         = state0q;
    apb0_psel     = 1'b0;
    apb1_psel     = 1'b0;
    apb0_penable  = 1'b0;
    apb1_penable  = 1'b0;
    apb0_pready   = 1'b0;
    apb1_pready   = 1'b0;
    
    unique case (state0q)
      ST_IDLE: begin
        if (i_apb0_psel) begin //Give priority to APB0
          state = ST_APB0_SETUP;
        end else if (~i_apb0_psel & i_apb1_psel) begin
          state = ST_APB1_SETUP;
        end
      end
      ST_APB0_SETUP: begin
        grant        = 2'b01;
        apb0_psel    = 1'b1;
        state        = ST_APB0_ACCESS;
      end
      ST_APB0_ACCESS: begin
        grant        = 2'b01;
        apb0_psel    = 1'b1;
        apb0_penable = 1'b1;
        apb0_pready  = i_apb_pready;
        if (i_apb_pready) begin
          state      = ST_IDLE;
        end
      end
      ST_APB1_SETUP: begin
        grant        = 2'b10;
        apb1_psel    = 1'b1;
        state        = ST_APB1_ACCESS;
      end
      ST_APB1_ACCESS: begin
        grant        = 2'b10;
        apb1_psel    = 1'b1;
        apb1_penable = 1'b1;
        apb1_pready  = i_apb_pready;
        if (i_apb_pready) begin
          state      = ST_IDLE;
        end
      end
    endcase
  end

  assign o_apb_paddr    = grant[0] ? i_apb0_paddr    : grant[1] ? i_apb1_paddr    : {APB_ADDR_WIDTH{1'b0}};
  assign o_apb_pprot    = grant[0] ? i_apb0_pprot    : grant[1] ? i_apb1_pprot    : 3'b0;
  assign o_apb_psel     = grant[0] ? apb0_psel       : grant[1] ? apb1_psel       : 1'b0;
  assign o_apb_penable  = grant[0] ? apb0_penable    : grant[1] ? apb1_penable    : 1'b0;
  assign o_apb_pwrite   = grant[0] ? i_apb0_pwrite   : grant[1] ? i_apb1_pwrite   : 1'b0;
  assign o_apb_pwdata   = grant[0] ? i_apb0_pwdata   : grant[1] ? i_apb1_pwdata   : {APB_DATA_WIDTH{1'b0}};
  assign o_apb_pstrb    = grant[0] ? i_apb0_pstrb    : grant[1] ? i_apb1_pstrb    : {APB_STRB_WIDTH{1'b0}};
  assign o_apb_pauser   = grant[0] ? i_apb0_pauser   : grant[1] ? i_apb1_pauser   : 32'b0;
  
  assign o_apb0_pready  = apb0_pready;
  assign o_apb0_pslverr = grant[0] ? i_apb_pslverr   : 1'b0;
  assign o_apb0_prdata  = grant[0] ? i_apb_prdata    : {APB_DATA_WIDTH{1'b0}};
  
  assign o_apb1_pready  = apb1_pready;
  assign o_apb1_pslverr = grant[1] ? i_apb_pslverr   : 1'b0;
  assign o_apb1_prdata  = grant[1] ? i_apb_prdata    : {APB_DATA_WIDTH{1'b0}};

endmodule
