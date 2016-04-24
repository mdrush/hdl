`include "reg16_8.v"
`include "alu.v"
`include "control.v"
`include "memory.v"

module datapath(clk);
    input clk;
    reg [15:0] IR;

    reg[15:0] global;
    wire [38:0] currentcs;
    reg BEN; //p131-132
    reg R;

    reg [2:0] SR1;
    reg [2:0] SR2;

    reg [2:0] DR;
    reg [15:0] addr1;
    reg [15:0] addr2;
    reg [15:0] PC;
    reg [15:0] adder;
    wire [15:0] SR1_OUT;
    wire [15:0] SR2_OUT;
    reg [15:0] SR2MUX_OUT;
    reg [15:0] SPMUX_OUT;
    reg [15:0] MARMUX_OUT;
    reg [7:0] Vector;

    wire [15:0] SP;
    reg [15:0] SavedSSP;
    reg [15:0] SavedUSP;

    wire INT;
    reg N;
    reg Z;
    reg P;

    reg [15:0] MAR;
    reg [15:0] MDR;

    wire [15:0] d_out;
    reg [15:0] d_in;

    wire [15:0] ALU_OUT;


reg16_8 REGFILE(.clk(clk),
    .ld_reg(currentcs[33]),
    .SR1(SR1),
    .SR2(SR2),
    .DR(DR),
    .SR1_OUT(SR1_OUT),
    .SR2_OUT(SR2_OUT),
    .global(global));


alu ALU(.A(SR1_OUT),
    .B(SR2MUX_OUT),
    .ALUK(currentcs[4:3]),
    .OUT(ALU_OUT));

control CONTROL(.clk(clk),
	.BEN(BEN),
    .IR(IR),
    .R(R),
    .PSR(PSR[15]),
    .INT(INT),
    .currentcs(currentcs));

memory MEMORY(.clk(clk),
	.MIO_EN(currentcs[2]),
	.R_W(currentcs[1]),
	.a(MARMUX_OUT),
	.d_out(d_out),
	.d_in(d_in),
	.global(global));

initial begin
	BEN = 0;
	R = 1;
	PC = 16'h0000;
	IR = 16'h0000;
end

always @(currentcs) begin

	if (currentcs[25]) // GateALU
		assign global = ALU_OUT;
	else if (currentcs[24]) // GateMARMUX 
		assign global = MARMUX_OUT;
	else if (currentcs[27]) // GatePC
		assign global = PC;
	else if (currentcs[26]) //GateMDR
		assign global = MDR;
	else if (currentcs[23]) //GateVector
		assign global = {8'h01, Vector};
	else if (currentcs[22]) //GatePC-1
		assign global = PC - 16'b1;
	else if (currentcs[21]) //GatePSR
		assign global = PSR;
	else if (currentcs[20]) //GateSP
		assign global = SP;

	if (currentcs[36]) // LD_IR
		IR <= global;
	
	if (currentcs[33]) begin //LD_CC
    	N <= global[15];
    	P <= ~global[15] & (|global); //Reduction Operators
    	Z <= ~global[15] & ~(|global);
    end

    if (currentcs[35]) begin
    	BEN <= ((IR[11] & N) | (IR[10] & Z) | (IR[9] & P));
    end

	/* DRMUX */
    case (currentcs[17:16])
        0 : DR <= IR[11:9];
        1 : DR <= 3'b110; //R6
        2 : DR <= 3'b111; //R7
    endcase

    /* SR1MUX */
    case (currentcs[15:14])
        2'b00 : SR1 <= IR[11:9];
        2'b01 : SR1 <= IR[8:6];
        2'b10 : SR1 <= 3'b110; //R6
    endcase
    
    /* SR2MUX */
    case (IR[5])
        0 : begin
                SR2 <= IR[2:0];
                SR2MUX_OUT <= SR2_OUT;
            end
        1 : SR2MUX_OUT <= {{11{IR[4]}}, IR[4:0]}; //SEXT
    endcase

    assign adder = addr1 + addr2;

    
    if (currentcs[32]) begin //LD_PC
    	case (currentcs[19:18]) /* PCMUX */
    	    0 : assign PC = PC + 16'b1;
    	    1 : assign PC = global;
    	    2 : assign PC = adder;
   		endcase
   	end

    /* ADDR1MUX */
    case (currentcs[13])
         0 : addr1 <= PC;
         1 : addr1 <= SR1_OUT;
    endcase

    /* ADDR2MUX */
    case (currentcs[12:11])
        0 : addr2 <= 0;
        1 : addr2 <= {{10{IR[5]}}, IR[5:0]}; //offset6, select SEXT[IR[5:0]]
        2 : addr2 <= {{7{IR[5]}}, IR[8:0]}; //PCoffset9, select SEXT[IR[8:0]]
        3 : addr2 <= {{5{IR[5]}}, IR[10:0]}; //PCoffset11, select SEXT[IR[10:0]]
    endcase

    /* SPMUX */
    case (currentcs[10:9])
    	0 : SPMUX_OUT <= SP + 16'b1;
    	1 : SPMUX_OUT <= SP - 16'b1;
    	2 : SPMUX_OUT <= SavedSSP;
    	3 : SPMUX_OUT <= SavedUSP;
    endcase

    /* MARMUX */
    case (currentcs[8])
    	1 : MARMUX_OUT <= {{8{1'b0}}, IR[7:0]}; //ZEXT[IR[7:0]]
    	0 : MARMUX_OUT <= adder;
   	endcase

	if (currentcs[38]) begin // LD_MAR 
  		MAR <= global;
  	end

  	if (currentcs[37]) begin // LD_MDR
  		assign MDR = d_out;
  	end

    if (currentcs[28]) begin /* LD_Vector */
    	/* VectorMUX */
    	case (currentcs[7:6])
    		0 : Vector <= IR[7:0]; //INTV
    		1 : Vector <= 8'h00; //Priv.exception
    		2 : Vector <= 8'h01; //Opc.exception
  	  endcase
  	end


	// /* PSRMUX */
 //  	case (currentcs[5])
 //  		0 : assign //individual settings
 //  		1 : assign //BUS
 //  	endcase 



end

endmodule