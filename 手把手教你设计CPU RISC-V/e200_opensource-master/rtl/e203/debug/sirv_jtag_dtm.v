 /*                                                                      
 Copyright 2017 Silicon Integrated Microelectronics, Inc.                
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
  Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */                                                                      
                                                                         
                                                                         
                                                                         


module sirv_jtag_dtm (
                   
                                 //JTAG Interface
                                 
                                 jtag_TDI,
                                 jtag_TDO,
                                 jtag_TCK,
                                 jtag_TMS,
                                 jtag_TRST,
                             
                                 jtag_DRV_TDO,

                                 dtm_req_valid,
                                 dtm_req_ready,
                                 dtm_req_bits,

                                 dtm_resp_valid,
                                 dtm_resp_ready,
                                 dtm_resp_bits
                                                                  
                                 );
   //--------------------------------------------------------
   // Parameter Declarations
   
   parameter ASYNC_FF_LEVELS  = 2;

   parameter DEBUG_DATA_BITS  = 34;
   parameter DEBUG_ADDR_BITS = 5; // Spec allows values are 5-7 
   parameter DEBUG_OP_BITS = 2; // OP and RESP are the same size.

   parameter JTAG_VERSION  = 4'h1;
   parameter JTAG_PART_NUM = 16'h0E31; // E31
   parameter JTAG_MANUF_ID = 11'h489;  // As Assigned by JEDEC

   // Number of cycles which must remain in IDLE
   // The software should handle even if the
   // answer is actually higher than this, or
   // the software may choose to ignore it entirely
   // and just check for busy.
   parameter DBUS_IDLE_CYCLES = 3'h5;

   localparam IR_BITS = 5;

   localparam DEBUG_VERSION = 0;
   
   // JTAG State Machine
   localparam TEST_LOGIC_RESET  = 4'h0;
   localparam RUN_TEST_IDLE     = 4'h1;
   localparam SELECT_DR         = 4'h2;
   localparam CAPTURE_DR        = 4'h3;
   localparam SHIFT_DR          = 4'h4;
   localparam EXIT1_DR          = 4'h5;
   localparam PAUSE_DR          = 4'h6;
   localparam EXIT2_DR          = 4'h7;
   localparam UPDATE_DR         = 4'h8;
   localparam SELECT_IR         = 4'h9;
   localparam CAPTURE_IR        = 4'hA;
   localparam SHIFT_IR          = 4'hB;
   localparam EXIT1_IR          = 4'hC;
   localparam PAUSE_IR          = 4'hD;
   localparam EXIT2_IR          = 4'hE;
   localparam UPDATE_IR         = 4'hF;

   //RISCV DTM Registers (see RISC-V Debug Specification)
   // All others are treated as 'BYPASS'.
   localparam REG_BYPASS       = 5'b11111;
   localparam REG_IDCODE       = 5'b00001;
   localparam REG_DEBUG_ACCESS = 5'b10001;
   localparam REG_DTM_INFO     = 5'b10000;

   localparam DBUS_REG_BITS = DEBUG_OP_BITS + DEBUG_ADDR_BITS + DEBUG_DATA_BITS;
   localparam DBUS_REQ_BITS = DEBUG_OP_BITS + DEBUG_ADDR_BITS + DEBUG_DATA_BITS;
   localparam DBUS_RESP_BITS = DEBUG_OP_BITS + DEBUG_DATA_BITS;
   
      
   localparam SHIFT_REG_BITS = DBUS_REG_BITS;

   //--------------------------------------------------------
   // I/O Declarations
   
   //JTAG SIDE
   input                                jtag_TDI;
   output reg                           jtag_TDO;
   input                                jtag_TCK;
   input                                jtag_TMS;
   input                                jtag_TRST;

   // To allow tri-state outside of this block.
   output reg                           jtag_DRV_TDO;

   // RISC-V Core Side

   output                               dtm_req_valid;
   input                                dtm_req_ready;
   output [DBUS_REQ_BITS - 1 :0]        dtm_req_bits;

   input                                dtm_resp_valid;
   output                               dtm_resp_ready;
   input [DBUS_RESP_BITS - 1 : 0]       dtm_resp_bits;
   
   wire                                 i_dtm_req_valid;
   wire                                 i_dtm_req_ready;
   wire [DBUS_REQ_BITS - 1 :0]          i_dtm_req_bits;

   wire                                 i_dtm_resp_valid;
   wire                                 i_dtm_resp_ready;
   wire[DBUS_RESP_BITS - 1 : 0]         i_dtm_resp_bits;
   //--------------------------------------------------------
   // Reg and Wire Declarations 
   
   reg [IR_BITS -1 : 0 ]                irReg;
   
   wire [31:0]                          idcode;
   wire [31:0]                          dtminfo;
   reg [DBUS_REG_BITS - 1 : 0]          dbusReg;
   reg                                  dbusValidReg;
   
   reg [3:0]                            jtagStateReg;
   
   reg [SHIFT_REG_BITS -1 : 0]          shiftReg;

   reg                                  doDbusWriteReg;
   reg                                  doDbusReadReg;

   reg                                  busyReg;
   reg                                  stickyBusyReg;
   reg                                  stickyNonzeroRespReg;
      
   reg                                  skipOpReg; // Skip op because we're busy.
   reg                                  downgradeOpReg; // Downgrade op because prev. op failed.

   wire                                 busy;
   wire                                 nonzeroResp;

   wire [SHIFT_REG_BITS -1 : 0]         busyResponse;
   wire [SHIFT_REG_BITS -1 : 0]         nonbusyResponse;
   
   //--------------------------------------------------------
   // Combo Logic

   assign idcode  = {JTAG_VERSION, JTAG_PART_NUM, JTAG_MANUF_ID, 1'h1};

   wire [3:0]                           debugAddrBits = DEBUG_ADDR_BITS[3:0];
   wire [3:0]                           debugVersion = DEBUG_VERSION[3:0];

   wire [1:0]                           dbusStatus;
   wire [2:0]                           dbusIdleCycles;

   wire                                 dbusReset;
   
   assign dbusIdleCycles = DBUS_IDLE_CYCLES;
   assign dbusStatus = {stickyNonzeroRespReg, stickyNonzeroRespReg | stickyBusyReg};
   assign dbusReset = shiftReg[16];

   assign dtminfo = {15'b0,
                     1'b0, // dbusreset goes here but is write-only
                     3'b0, 
                     dbusIdleCycles, 
                     dbusStatus, 
                     debugAddrBits, 
                     debugVersion};
   
   //busy, dtm_resp* is only valid during CAPTURE_DR,
   //      so these signals should only be used at that time.
   // This assumes there is only one transaction in flight at a time.
   assign busy = (busyReg & ~i_dtm_resp_valid) | stickyBusyReg;
   // This is needed especially for the first request.
   assign nonzeroResp = (i_dtm_resp_valid ? | {i_dtm_resp_bits[DEBUG_OP_BITS-1:0]} : 1'b0) | stickyNonzeroRespReg;
   
   // Interface to DM.
   // Note that this means i_dtm_resp_bits must only be used during CAPTURE_DR.
   assign i_dtm_resp_ready = (jtagStateReg == CAPTURE_DR) &&
                           (irReg        == REG_DEBUG_ACCESS) &&
                           i_dtm_resp_valid;
      
   assign i_dtm_req_valid = dbusValidReg;
   assign i_dtm_req_bits  = dbusReg;
   
   assign busyResponse  = {{(DEBUG_ADDR_BITS +  DEBUG_DATA_BITS){1'b0}},
                           {(DEBUG_OP_BITS){1'b1}}};                                    // Generalizing 'busy' to 'all-1'
   
   assign nonbusyResponse =  {dbusReg[(DEBUG_DATA_BITS + DEBUG_OP_BITS) +: DEBUG_ADDR_BITS] ,     // retain address bits from Req. 
                              i_dtm_resp_bits[DEBUG_OP_BITS +: DEBUG_DATA_BITS] ,                   // data
                              i_dtm_resp_bits[0 +: DEBUG_OP_BITS]                                   // response
                              };
      
   //--------------------------------------------------------
   // Sequential Logic

   // JTAG STATE MACHINE

   always @(posedge jtag_TCK or posedge jtag_TRST) begin
      if (jtag_TRST) begin
         jtagStateReg <= TEST_LOGIC_RESET;
      end else begin
         case (jtagStateReg)
           TEST_LOGIC_RESET  : jtagStateReg <= jtag_TMS ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
           RUN_TEST_IDLE     : jtagStateReg <= jtag_TMS ? SELECT_DR        : RUN_TEST_IDLE;
           SELECT_DR         : jtagStateReg <= jtag_TMS ? SELECT_IR        : CAPTURE_DR;
           CAPTURE_DR        : jtagStateReg <= jtag_TMS ? EXIT1_DR         : SHIFT_DR;
           SHIFT_DR          : jtagStateReg <= jtag_TMS ? EXIT1_DR         : SHIFT_DR;
           EXIT1_DR          : jtagStateReg <= jtag_TMS ? UPDATE_DR        : PAUSE_DR;
           PAUSE_DR          : jtagStateReg <= jtag_TMS ? EXIT2_DR         : PAUSE_DR;
           EXIT2_DR          : jtagStateReg <= jtag_TMS ? UPDATE_DR        : SHIFT_DR;
           UPDATE_DR         : jtagStateReg <= jtag_TMS ? SELECT_DR        : RUN_TEST_IDLE;
           SELECT_IR         : jtagStateReg <= jtag_TMS ? TEST_LOGIC_RESET : CAPTURE_IR;
           CAPTURE_IR        : jtagStateReg <= jtag_TMS ? EXIT1_IR         : SHIFT_IR;
           SHIFT_IR          : jtagStateReg <= jtag_TMS ? EXIT1_IR         : SHIFT_IR;
           EXIT1_IR          : jtagStateReg <= jtag_TMS ? UPDATE_IR        : PAUSE_IR;
           PAUSE_IR          : jtagStateReg <= jtag_TMS ? EXIT2_IR         : PAUSE_IR;
           EXIT2_IR          : jtagStateReg <= jtag_TMS ? UPDATE_IR        : SHIFT_IR;
           UPDATE_IR         : jtagStateReg <= jtag_TMS ? SELECT_DR        : RUN_TEST_IDLE; 
         endcase // case (jtagStateReg)
      end // else: !if(jtag_TRST)
   end // always @ (posedge jtag_TCK or posedge jtag_TRST)

   // SHIFT REG 
   always @(posedge jtag_TCK) begin
      case (jtagStateReg)
        CAPTURE_IR : shiftReg <= {{(SHIFT_REG_BITS-1){1'b0}}, 1'b1}; //JTAG spec only says must end with 'b01. 
        SHIFT_IR   : shiftReg <= {{(SHIFT_REG_BITS-IR_BITS){1'b0}}, jtag_TDI, shiftReg[IR_BITS-1 : 1]};
        CAPTURE_DR : case (irReg) 
                       REG_BYPASS       : shiftReg <= {(SHIFT_REG_BITS){1'b0}};
                       REG_IDCODE       : shiftReg <= {{(SHIFT_REG_BITS-32){1'b0}}, idcode};
                       REG_DTM_INFO     : shiftReg <= {{(SHIFT_REG_BITS-32){1'b0}}, dtminfo};
                       REG_DEBUG_ACCESS : shiftReg <= busy ? busyResponse : nonbusyResponse;
                       default : //BYPASS
                         shiftReg <= {(SHIFT_REG_BITS){1'b0}};
                     endcase
        SHIFT_DR   : case (irReg) 
                       REG_BYPASS   : shiftReg <= {{(SHIFT_REG_BITS- 1){1'b0}}, jtag_TDI};
                       REG_IDCODE   : shiftReg <= {{(SHIFT_REG_BITS-32){1'b0}}, jtag_TDI, shiftReg[31:1]};
                       REG_DTM_INFO : shiftReg <= {{(SHIFT_REG_BITS-32){1'b0}}, jtag_TDI, shiftReg[31:1]};
                       REG_DEBUG_ACCESS : shiftReg <= {jtag_TDI, shiftReg[SHIFT_REG_BITS -1 : 1 ]};
                       default: // BYPASS
                        shiftReg <= {{(SHIFT_REG_BITS- 1){1'b0}} , jtag_TDI};
                     endcase // case (irReg)  
      endcase // case (jtagStateReg)
   end

   // IR 
   always @(negedge jtag_TCK or posedge jtag_TRST) begin
      if (jtag_TRST) begin
         irReg <= REG_IDCODE;
      end else if (jtagStateReg == TEST_LOGIC_RESET) begin
         irReg <= REG_IDCODE;
      end else if (jtagStateReg == UPDATE_IR) begin
         irReg <= shiftReg[IR_BITS-1:0];
      end
   end
  
   // Busy. We become busy when we first try to send a request.
   // We stop being busy when we accept a response.
   // This means that busyReg will still be set when we check it,
   // so the logic for checking busy looks ahead.
   
   always @(posedge jtag_TCK or posedge jtag_TRST) begin
      if (jtag_TRST) begin
         busyReg <= 1'b0;
      end else if (i_dtm_req_valid) begin //UPDATE_DR onwards
         busyReg <= 1'b1;
      end else if (i_dtm_resp_valid & i_dtm_resp_ready) begin //only in CAPTURE_DR
         busyReg <= 1'b0;
      end
   end // always @ (posedge jtag_TCK or posedge jtag_TRST)


   // Downgrade/Skip. We make the decision to downgrade or skip
   // during every CAPTURE_DR, and use the result in UPDATE_DR.
   always @(posedge jtag_TCK or posedge jtag_TRST) begin
      if (jtag_TRST) begin
         skipOpReg            <= 1'b0;
         downgradeOpReg       <= 1'b0;
         stickyBusyReg        <= 1'b0;
         stickyNonzeroRespReg <= 1'b0;
      end else if (irReg == REG_DEBUG_ACCESS) begin
         case(jtagStateReg)
           CAPTURE_DR: begin
              skipOpReg      <= busy;
              downgradeOpReg <= (~busy & nonzeroResp);
              stickyBusyReg  <= busy;
              stickyNonzeroRespReg <= nonzeroResp;
           end
           UPDATE_DR: begin
              skipOpReg      <= 1'b0;
              downgradeOpReg <= 1'b0;
           end
         endcase // case (jtagStateReg)
      end else if (irReg == REG_DTM_INFO) begin
         case(jtagStateReg)
           UPDATE_DR: begin
              if (dbusReset) begin
                 stickyNonzeroRespReg <= 1'b0;
                 stickyBusyReg        <= 1'b0;
              end
           end
         endcase // case (jtagStateReg)
      end
   end // always @ (posedge jtag_TCK or posedge jtag_TRST)
   
   
   //dbusReg, dbusValidReg.
   always @(posedge jtag_TCK or posedge jtag_TRST) begin
      if (jtag_TRST) begin
         dbusReg <= {(DBUS_REG_BITS) {1'b0}};
         dbusValidReg <= 1'b0;
      end else if (jtagStateReg == UPDATE_DR) begin
         if (irReg == REG_DEBUG_ACCESS) begin
            if (skipOpReg) begin
               // do nothing.
            end else if (downgradeOpReg) begin
               dbusReg      <= {(DBUS_REG_BITS){1'b0}}; // NOP has encoding 2'b00.
               dbusValidReg <= 1'b1;
            end else begin 
               dbusReg      <= shiftReg[DBUS_REG_BITS-1:0];
               dbusValidReg <= 1'b1;
            end
         end
      end else if (i_dtm_req_ready) begin
         dbusValidReg <= 1'b0;
      end
   end // always @ (negedge jtag_TCK or posedge jtag_TRST)
        
   //TDO
   always @(negedge jtag_TCK or posedge jtag_TRST) begin
      if (jtag_TRST) begin
         jtag_TDO     <= 1'b0;
         jtag_DRV_TDO <= 1'b0;
      end else if (jtagStateReg == SHIFT_IR) begin
         jtag_TDO     <= shiftReg[0];
         jtag_DRV_TDO <= 1'b1;
      end else if (jtagStateReg == SHIFT_DR) begin
         jtag_TDO     <= shiftReg[0];
         jtag_DRV_TDO <= 1'b1;
      end else begin
         jtag_TDO     <= 1'b0;
         jtag_DRV_TDO <= 1'b0;
      end
   end // always @ (negedge jtag_TCK or posedge jtag_TRST)
   
     sirv_gnrl_cdc_tx   
   # (
     .DW      (41),
     .SYNC_DP (ASYNC_FF_LEVELS) 
   ) u_jtag2debug_cdc_tx (
     .o_vld  (dtm_req_valid), 
     .o_rdy_a(dtm_req_ready), 
     .o_dat  (dtm_req_bits ),
     .i_vld  (i_dtm_req_valid), 
     .i_rdy  (i_dtm_req_ready), 
     .i_dat  (i_dtm_req_bits ),
   
     .clk    (jtag_TCK),
     .rst_n  (~jtag_TRST)
   );
     
   sirv_gnrl_cdc_rx   
      # (
     .DW      (36),
     .SYNC_DP (ASYNC_FF_LEVELS) 
   ) u_jtag2debug_cdc_rx (
     .i_vld_a(dtm_resp_valid), 
     .i_rdy  (dtm_resp_ready), 
     .i_dat  (dtm_resp_bits ),
     .o_vld  (i_dtm_resp_valid), 
     .o_rdy  (i_dtm_resp_ready), 
     .o_dat  (i_dtm_resp_bits ),
   
     .clk    (jtag_TCK),
     .rst_n  (~jtag_TRST)
   );

endmodule

   
