module iic_ctrl(
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire iic_start,
    input wire addr_mem,////////接受寄存器位置是8位还是16位
    input wire [15:0] data_addr,
    input wire [7:0] wr_data,

	inout wire i2c_sda,
    output reg [7:0] rd_data,   //输出i2c设备读取数据
    output reg i2c_end,   //i2c一次读/写操作完成
    output reg i2c_scl
);

reg [3:0] state;
reg iic_work_clk;/////////1MHZ工作时钟，计数小，节省空间
reg [4:0]iic_work_clk_cnt;
reg [2:0] cnt_bit;
reg [1:0] iic_clk_cnt;
reg iic_clk_en;

wire sda_in;   //sda输入数据寄存
wire sda_en;   //sda数据写入使能信号
reg ack;////////////应答信号
reg i2c_sda_reg     ;   //sda数据缓存
reg [7:0] rd_data_reg     ;   //自i2c设备读出数据
parameter   DEVICE_ADDR     =   7'b1010_011     ;   //i2c设备地址
parameter       
    IDLE            =   4'd00,  //初始状态
	START_1         =   4'd01,  //开始状态1
	SEND_D_ADDR     =   4'd02,  //设备地址写入状态 + 控制写
	ACK_1           =   4'd03,  //应答状态1
	SEND_B_ADDR_H   =   4'd04,  //字节地址高八位写入状态
	ACK_2           =   4'd05,  //应答状态2
	SEND_B_ADDR_L   =   4'd06,  //字节地址低八位写入状态
	ACK_3           =   4'd07,  //应答状态3
	WR_DATA         =   4'd08,  //写数据状态
	ACK_4           =   4'd09,  //应答状态4
	START_2         =   4'd10,  //开始状态2
	SEND_RD_ADDR    =   4'd11,  //设备地址写入状态 + 控制读
	ACK_5           =   4'd12,  //应答状态5
	RD_DATA         =   4'd13,  //读数据状态
	N_ACK           =   4'd14,  //非应答状态
	STOP            =   4'd15;  //结束状态


always @(posedge clk or negedge rst_n) ///////////////////////////1MHZ时钟计数器
    begin
        if(~rst_n)
            iic_work_clk_cnt <= 5'd0;
        else if(iic_work_clk_cnt == 5'd24)
            iic_work_clk_cnt <= 5'd0;
        else
            iic_work_clk_cnt <= iic_work_clk_cnt + 5'd1;
    end

always @(posedge clk or negedge rst_n) //////////////////////////////1MHZ时钟
    begin
        if(~rst_n)
            iic_work_clk <= 1'd0;
        else if(iic_work_clk_cnt == 5'd24)
            iic_work_clk <= ~iic_work_clk;
        else
            iic_work_clk <= iic_work_clk;
    end


always @(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
            iic_clk_en <= 1'd0;
        else if(cnt_bit == 3'd3 && iic_clk_cnt == 2'd3 && (state == STOP))
            iic_clk_en <= 1'd0; 
        else if(iic_start)
            iic_clk_en <= 1'd1;
    end


always @(posedge iic_work_clk or negedge rst_n)
    begin
        if(~rst_n)
            iic_clk_cnt <= 1'd0;
        else if(iic_clk_en)
            iic_clk_cnt <= iic_clk_cnt + 1'd1;
    end

always @(posedge iic_work_clk or negedge rst_n)
    begin
        if(~rst_n)
            cnt_bit <= 3'd0;
        else if((state == IDLE) || (state == START_1) || (state == START_2)
				|| (state == ACK_1) || (state == ACK_2) || (state == ACK_3)
				|| (state == ACK_4) || (state == ACK_5) || (state == N_ACK))
			cnt_bit <=  3'd0;
        else if(cnt_bit == 3'd7 && iic_clk_cnt == 2'd3)
            cnt_bit <= 3'd0;
        else if(iic_clk_cnt == 2'd3 && state != IDLE)
            cnt_bit <= cnt_bit + 3'd1;
    end

// sda_in:sda输入数据寄存
assign  sda_in = i2c_sda;

// ack:应答信号
always@(*)
	case(state)
		  IDLE,START_1,SEND_D_ADDR,SEND_B_ADDR_H,SEND_B_ADDR_L,
		  WR_DATA,START_2,SEND_RD_ADDR,RD_DATA,N_ACK:
				ack <=  1'b1;
		  ACK_1,ACK_2,ACK_3,ACK_4,ACK_5:
				if(iic_clk_cnt == 2'd0)
					ack <=  sda_in;//1'b0;//
				else
					ack <=  ack;
		  default:    ack <=  1'b1;
	endcase


always @(posedge iic_work_clk or negedge rst_n)
    begin
        if(~rst_n)
            state <= IDLE;
        else
            case (state)
                IDLE:
                    begin
                        if(iic_start)
                            state <= START_1;
                        else
                            state <= state;
                    end
                START_1:
                    begin
                        if(iic_clk_cnt == 2'd3)
                            state <= SEND_D_ADDR;
                        else
                            state <= state;
                    end
                SEND_D_ADDR:
                    begin
                        if(cnt_bit == 3'd7 && iic_clk_cnt == 2'd3)
                            state <= ACK_1;
                        else
                            state <= state;
                    end
                ACK_1:
                    begin
                        if(ack == 1'b0 && iic_clk_cnt == 2'd3)
                            begin
                                if(addr_mem == 1'b1)
                                    state   <=  SEND_B_ADDR_H;
							  else
									state   <=  SEND_B_ADDR_L;
                            end    
                    end
                SEND_B_ADDR_H:///如果寄存器地址是16位宽的，需要跳转到当前状态
                    begin
                        if(cnt_bit == 3'd7 && iic_clk_cnt == 2'd3)
                            state <= ACK_2;
                        else
                            state <= state;
                    end
                ACK_2:////发送了寄存器地址的最高的1个字节地址之后，需要从机应答一次
                    begin
                        if((iic_clk_cnt == 2'd3) && (ack == 1'b0))
						    state   <=  SEND_B_ADDR_L;
					    else
						    state   <=  state;
                    end
                SEND_B_ADDR_L: ////发送寄存器地址的   低
                    begin
					    if((cnt_bit == 3'd7) && (iic_clk_cnt == 2'd3))
						    state   <=  ACK_3;
					    else
						    state   <=  state;
                    end
                ACK_3:
                    begin
					    if((iic_clk_cnt == 3) && (ack == 1'b0))
					    	begin
					    		if(wr_en == 1'b1)
					    			state   <=  WR_DATA;
					    		else if(rd_en == 1'b1)
					    			state   <=  START_2;
					    		else
					    			state   <=  state;
					    	end
					    else
					    	state   <=  state;
                    end
                WR_DATA:
                    begin
                        if((cnt_bit == 3'd7) &&(iic_clk_cnt == 3))
						    state   <=  ACK_4;
					    else
						    state   <=  state;
                    end
                ACK_4:
                    begin
                        if((iic_clk_cnt == 3) && (ack == 1'b0))
						    state   <=  STOP;
					    else
						    state   <=  state;
                    end
                START_2:
                    begin
                        if(iic_clk_cnt == 3)
						    state   <=  SEND_RD_ADDR;
					    else
						    state   <=  state;
                    end
                SEND_RD_ADDR:
                    begin
                        if((cnt_bit == 3'd7) &&(iic_clk_cnt == 3))
						    state   <=  ACK_5;
					    else
						    state   <=  state;
                    end
                ACK_5:
                    begin
                        if((iic_clk_cnt == 3) && (ack == 1'b0))
						    state   <=  RD_DATA;
					    else
						    state   <=  state;
                    end
                RD_DATA:
                    begin
                        if((cnt_bit == 3'd7) &&(iic_clk_cnt == 3))
						    state   <=  N_ACK;
					    else
						    state   <=  state;
                    end
                N_ACK:
                    begin
                        if(iic_clk_cnt == 3)
						    state   <=  STOP;
					    else
						    state   <=  state;
                    end      
                STOP:
                    begin
                        if((cnt_bit == 3'd3) &&(iic_clk_cnt == 3))
						    state   <=  IDLE;
					    else
						    state   <=  state;
                    end     
                default: state   <=  IDLE;
            endcase
    end

	// i2c_scl:输出至i2c设备的串行时钟信号scl
always @(*)
	 case(state)
		IDLE:
			i2c_scl <=  1'b1;
		START_1:
			if(iic_clk_cnt == 2'd3)
				 i2c_scl <=  1'b0;
			else
				 i2c_scl <=  1'b1;
		SEND_D_ADDR,ACK_1,SEND_B_ADDR_H,ACK_2,SEND_B_ADDR_L,
		ACK_3,WR_DATA,ACK_4,START_2,SEND_RD_ADDR,ACK_5,RD_DATA,N_ACK:
			if((iic_clk_cnt == 2'd1) || (iic_clk_cnt == 2'd2))
				 i2c_scl <=  1'b1;
			else
				 i2c_scl <=  1'b0;
		STOP:
			if((cnt_bit == 3'd0) &&(iic_clk_cnt == 2'd0))
				 i2c_scl <=  1'b0;
			else
				 i2c_scl <=  1'b1;
		default:    i2c_scl <=  1'b1;
	 endcase

// i2c_sda_reg:sda数据缓存
always@(*)
	 case(state)
		  IDLE:
				begin
					 i2c_sda_reg <=  1'b1;
					 rd_data_reg <=  8'd0;
				end
		  START_1:
				if(iic_clk_cnt <= 2'd0)
					 i2c_sda_reg <=  1'b1;
				else
					 i2c_sda_reg <=  1'b0;
		  SEND_D_ADDR:
				if(cnt_bit <= 3'd6)
					 i2c_sda_reg <=  DEVICE_ADDR[6 - cnt_bit];
				else
					 i2c_sda_reg <=  1'b0;
		  ACK_1:
				i2c_sda_reg <=  1'b1;
		  SEND_B_ADDR_H:
				i2c_sda_reg <=  data_addr[15 - cnt_bit];
		  ACK_2:
				i2c_sda_reg <=  1'b1;
		  SEND_B_ADDR_L:
				i2c_sda_reg <=  data_addr[7 - cnt_bit];
		  ACK_3:
				i2c_sda_reg <=  1'b1;
		  WR_DATA:
				i2c_sda_reg <=  wr_data[7 - cnt_bit];
		  ACK_4:
				i2c_sda_reg <=  1'b1;
		  START_2:
				if(iic_clk_cnt <= 2'd1)
					 i2c_sda_reg <=  1'b1;
				else
					 i2c_sda_reg <=  1'b0;
		  SEND_RD_ADDR:
				if(cnt_bit <= 3'd6)
					 i2c_sda_reg <=  DEVICE_ADDR[6 - cnt_bit];
				else
					 i2c_sda_reg <=  1'b1;
		  ACK_5:
				i2c_sda_reg <=  1'b1;
		  RD_DATA:
				if(iic_clk_cnt  == 2'd2)
					 rd_data_reg[7 - cnt_bit]    <=  sda_in;
				else
					 rd_data_reg <=  rd_data_reg;
		  N_ACK:
				i2c_sda_reg <=  1'b1;
		  STOP:
				if((cnt_bit == 3'd0) && (iic_clk_cnt < 2'd3))
					 i2c_sda_reg <=  1'b0;
				else
					 i2c_sda_reg <=  1'b1;
		  default:
				begin
					 i2c_sda_reg <=  1'b1;
					 rd_data_reg <=  rd_data_reg;
				end
	 endcase

// rd_data:自i2c设备读出数据
always @(posedge iic_work_clk or negedge rst_n)
	 if(rst_n == 1'b0)
		  rd_data <=  8'd0;
	 else    if((state == RD_DATA) && (cnt_bit == 3'd7) && (iic_clk_cnt == 2'd3))
		  rd_data <=  rd_data_reg;

// i2c_end:一次读/写结束信号
always @(posedge iic_work_clk or negedge rst_n)
	 if(rst_n == 1'b0)
		  i2c_end <=  1'b0;
	 else    if((state == STOP) && (cnt_bit == 3'd3) &&(iic_clk_cnt == 3))
		  i2c_end <=  1'b1;
	 else
		  i2c_end <=  1'b0;
 
//	assign  sda_in = 0;
	
	// sda_en:sda数据写入使能信号
	assign  sda_en = ((state == RD_DATA) || (state == ACK_1) || (state == ACK_2)
							  || (state == ACK_3) || (state == ACK_4) || (state == ACK_5))
							  ? 1'b0 : 1'b1;

// i2c_sda:输出至i2c设备的串行数据信号sda
assign  i2c_sda = (sda_en == 1'b1) ? i2c_sda_reg : 1'bz;

endmodule