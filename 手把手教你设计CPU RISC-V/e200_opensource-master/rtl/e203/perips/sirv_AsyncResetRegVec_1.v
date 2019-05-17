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
                                                                         
                                                                         
                                                                         
module sirv_AsyncResetRegVec_1(
  input   clock,
  input   reset,
  input  [4:0] io_d,
  output [4:0] io_q,
  input   io_en
);
  wire  reg_0_rst;
  wire  reg_0_clk;
  wire  reg_0_en;
  wire  reg_0_q;
  wire  reg_0_d;
  wire  reg_1_rst;
  wire  reg_1_clk;
  wire  reg_1_en;
  wire  reg_1_q;
  wire  reg_1_d;
  wire  reg_2_rst;
  wire  reg_2_clk;
  wire  reg_2_en;
  wire  reg_2_q;
  wire  reg_2_d;
  wire  reg_3_rst;
  wire  reg_3_clk;
  wire  reg_3_en;
  wire  reg_3_q;
  wire  reg_3_d;
  wire  reg_4_rst;
  wire  reg_4_clk;
  wire  reg_4_en;
  wire  reg_4_q;
  wire  reg_4_d;
  wire  T_8;
  wire  T_9;
  wire  T_10;
  wire  T_11;
  wire  T_12;
  wire [1:0] T_13;
  wire [1:0] T_14;
  wire [2:0] T_15;
  wire [4:0] T_16;
  sirv_AsyncResetReg reg_0 (
    .rst(reg_0_rst),
    .clk(reg_0_clk),
    .en(reg_0_en),
    .q(reg_0_q),
    .d(reg_0_d)
  );
  sirv_AsyncResetReg reg_1 (
    .rst(reg_1_rst),
    .clk(reg_1_clk),
    .en(reg_1_en),
    .q(reg_1_q),
    .d(reg_1_d)
  );
  sirv_AsyncResetReg reg_2 (
    .rst(reg_2_rst),
    .clk(reg_2_clk),
    .en(reg_2_en),
    .q(reg_2_q),
    .d(reg_2_d)
  );
  sirv_AsyncResetReg reg_3 (
    .rst(reg_3_rst),
    .clk(reg_3_clk),
    .en(reg_3_en),
    .q(reg_3_q),
    .d(reg_3_d)
  );
  sirv_AsyncResetReg reg_4 (
    .rst(reg_4_rst),
    .clk(reg_4_clk),
    .en(reg_4_en),
    .q(reg_4_q),
    .d(reg_4_d)
  );
  assign io_q = T_16;
  assign reg_0_rst = reset;
  assign reg_0_clk = clock;
  assign reg_0_en = io_en;
  assign reg_0_d = T_8;
  assign reg_1_rst = reset;
  assign reg_1_clk = clock;
  assign reg_1_en = io_en;
  assign reg_1_d = T_9;
  assign reg_2_rst = reset;
  assign reg_2_clk = clock;
  assign reg_2_en = io_en;
  assign reg_2_d = T_10;
  assign reg_3_rst = reset;
  assign reg_3_clk = clock;
  assign reg_3_en = io_en;
  assign reg_3_d = T_11;
  assign reg_4_rst = reset;
  assign reg_4_clk = clock;
  assign reg_4_en = io_en;
  assign reg_4_d = T_12;
  assign T_8 = io_d[0];
  assign T_9 = io_d[1];
  assign T_10 = io_d[2];
  assign T_11 = io_d[3];
  assign T_12 = io_d[4];
  assign T_13 = {reg_1_q,reg_0_q};
  assign T_14 = {reg_4_q,reg_3_q};
  assign T_15 = {T_14,reg_2_q};
  assign T_16 = {T_15,T_13};
endmodule

