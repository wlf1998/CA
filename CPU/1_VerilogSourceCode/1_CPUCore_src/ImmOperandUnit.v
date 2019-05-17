`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB (Embeded System Lab)
// Engineer: Haojun Xia
// Create Date: 2019/02/08
// Design Name: RISCV-Pipline CPU
// Module Name: ImmOperandUnit
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: Generate different type of Immediate Operand
//////////////////////////////////////////////////////////////////////////////////
`include "Parameters.v"   
module ImmOperandUnit(
    input wire [31:7] In,
    input wire [2:0] Type,
    output reg [31:0] Out
    );
    //
    always@(*)
    begin
        case(Type)
            `RTYPE: Out<=32'b0;
            `ITYPE: Out<={ {21{In[31]}}, In[30:20] };
            `STYPE: Out<={ {21{In[31]}}, In[30:25],In[11:7]};
            `BTYPE: Out<={ {20{In[31]}},In[7],In[30:25],In[11:8],1'b0};   
            `UTYPE: Out<={ In[31:12],12'b0};
            `JTYPE: Out<={ {12{In[31]}},In[19:12],In[20],In[30:21],1'b0};                                    //请补全!!!
            default:Out<=32'hxxxxxxxx;
        endcase
    end
    
endmodule

/*
//ImmType[2:0]
    `define RTYPE  3'd0
    `define ITYPE  3'd1
    `define STYPE  3'd2
    `define BTYPE  3'd3
    `define UTYPE  3'd4
    `define JTYPE  3'd5 
*/

//功能说明
    //ImmOperandUnit利用正在被译码的指令的部分编码值，生成不同类型的32bit立即数
//输入
    //IN        是指令除了opcode以外的部分编码值
    //Type      表示立即数编码类型，全部类型定义在Parameters.v中
//输出
    //OUT       表示指令对应的立即数32bit实际值
//实验要求  
    //补全ImmOperandUnit模块  
    //待补全部分如下

    //always@(*)
    //begin
    //    case(Type)
    //        `ITYPE: Out<={ {21{In[31]}}, In[30:20] };
    //        //......                                        //请补全!!!
    //        default:Out<=32'hxxxxxxxx;
    //    endcase
    //end