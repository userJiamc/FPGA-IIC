module fsm(
    input wire clk,
    input wire rst_n,
    input wire key_wr,
    input wire key_rd,
    input wire iic_wr_rd_done,

    output reg wr_en,
    output reg rd_en,
    output reg iic_start,
    output reg addr_mem,////////接受寄存器位置是8位还是16位
    output reg [15:0] data_addr,
    output reg [7:0] wr_data  
);

reg [31:0] cnt_key_1;
wire key_flag_wr;

always @(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
            cnt_key_1 <= 32'd0;
        else if(key_wr)
            cnt_key_1 <= 32'd0;
        else if(cnt_key_1 == 32'd99_999)
            cnt_key_1 <= cnt_key_1;
        else
            cnt_key_1 <= cnt_key_1 + 32'd1;
    end

assign key_flag_wr = (cnt_key_1 == 32'd99_998)? 1'd1 : 1'd0;

reg [31:0] cnt_key_2;
wire key_flag_rd;

always @(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
            cnt_key_2 <= 32'd0;
        else if(key_rd)
            cnt_key_2 <= 32'd0;
        else if(cnt_key_2 == 32'd99_999)
            cnt_key_2 <= cnt_key_2;
        else
            cnt_key_2 <= cnt_key_2 + 32'd1;
    end

assign key_flag_rd = (cnt_key_2 == 32'd99_998)? 1'd1 : 1'd0;

reg [7:0] state;

parameter
    IDLE = 8'd0,
    S0 = 8'd1,
    S1 = 8'd2,
    S2 = 8'd3,
    S3 = 8'd4,
    S4 = 8'd5,
    S5 = 8'd6,
    S6 = 8'd7,
    S7 = 8'd8; 

always @(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
            begin
                state <= IDLE;
				wr_en <= 1'b0;
				rd_en <= 1'b0;
				iic_start <= 1'b0;
				addr_mem <= 1'b1;
				data_addr <= 16'd0;
				wr_data <= 8'h0;
            end
        else
            case (state)
                IDLE:
                    begin
                        if(key_flag_wr)
                            state <= S0;
                        else if(key_flag_rd)
                            state <= S3;
                        else
                            state <= state;
                    end
                S0:
                    begin
                        state <= S1;
                        wr_en <= 1'd1;
                        rd_en <= 1'b0;
                        iic_start <= 1'b1;
                        addr_mem <= 1'b1;
                        data_addr <= 16'h005A;
                        wr_data <= 8'h55;
                    end
                S1:
                    begin
                        if(iic_wr_rd_done)
                            begin
                                state <= S2;
                                wr_en <= 1'd0;
                                rd_en <= 1'b0;
                                iic_start <= 1'b0;
                                addr_mem <= 1'b1;
                                data_addr <= 16'h005A;
                                wr_data <= 8'h55;
                            end
                    end
                S2:
					begin 
						state <= IDLE;
					end     
                S3:
                    begin
                        state <= S4;
                        wr_en <= 1'd0;
                        rd_en <= 1'b1;
                        iic_start <= 1'b1;
                        addr_mem <= 1'b1;
                        data_addr <= 16'h005a;
                    end
                S4:
                    begin
                        if(iic_wr_rd_done)
                            begin
                                state <= S5;
                                wr_en <= 1'd0;
                                rd_en <= 1'b0;
                                iic_start <= 1'b0;
                                addr_mem <= 1'b1;
                                data_addr <= 16'h005a;
                            end
                    end
                S5:
					begin 
						state <= IDLE;
					end
                default: 
                    begin
                        state <= IDLE;
                    end
            endcase
    end
endmodule