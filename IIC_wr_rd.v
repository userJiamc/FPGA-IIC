module IIC_wr_rd(
    input wire clk,
    input wire rst_n,
    input wire key_wr,
    input wire key_rd,

	inout wire i2c_sda,
    output wire [7:0] rd_data,   //输出i2c设备读取数据
    output wire i2c_scl
);

wire wr_en;
wire rd_en;
wire iic_start;
wire addr_mem;////////接受寄存器位置是8位还是16位
wire [15:0] data_addr;
wire [7:0] wr_data;
wire iic_wr_rd_done;

fsm fsm(
.clk(clk),
.rst_n(rst_n),
.key_wr(key_wr),
.key_rd(key_rd),
.iic_wr_rd_done(iic_wr_rd_done),

.wr_en(wr_en),
.rd_en(rd_en),
.iic_start(iic_start),
.addr_mem(addr_mem),////////接受寄存器位置是8位还是16位
.data_addr(data_addr),
.wr_data(wr_data)  
);

iic_ctrl iic_ctrl(
.clk(clk),
.rst_n(rst_n),
.wr_en(wr_en),
.rd_en(rd_en),
.iic_start(iic_start),
.addr_mem(addr_mem),////////接受寄存器位置是8位还是16位
.data_addr(data_addr),
.wr_data(wr_data),

.i2c_sda(i2c_sda),
.rd_data(rd_data),   //输出i2c设备读取数据
.i2c_end(iic_wr_rd_done),   //i2c一次读/写操作完成
.i2c_scl(i2c_scl)
);

endmodule