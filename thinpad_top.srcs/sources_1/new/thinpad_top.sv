`default_nettype none

module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮�?关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时�? 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时�? 1
    output wire [15:0] leds,       // 16 �? LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信�?
    output wire uart_rdn,        // 读串口信号，低有�?
    output wire uart_wrn,        // 写串口信号，低有�?
    input  wire uart_dataready,  // 串口数据准备�?
    input  wire uart_tbre,       // 发�?�数据标�?
    input  wire uart_tsre,       // 数据发�?�完毕标�?

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共�?
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持�? 0
    output wire base_ram_ce_n,  // BaseRAM 片�?�，低有�?
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有�?
    output wire base_ram_we_n,  // BaseRAM 写使能，低有�?

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持�? 0
    output wire ext_ram_ce_n,  // ExtRAM 片�?�，低有�?
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有�?
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有�?

    // 直连串口信号
    output wire txd,  // 直连串口发�?�端
    input  wire rxd,  // 直连串口接收�?

    // Flash 存储器信号，参�?? JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效�?16bit 模式无意�?
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧�?
    output wire flash_ce_n,  // Flash 片�?�信号，低有�?
    output wire flash_oe_n,  // Flash 读使能信号，低有�?
    output wire flash_we_n,  // Flash 写使能信号，低有�?
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash �? 16 位模式时请设�? 1

    // USB 控制器信号，参�?? SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参�?? DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素�?3 �?
    output wire [2:0] video_green,  // 绿色像素�?3 �?
    output wire [1:0] video_blue,   // 蓝色像素�?2 �?
    output wire       video_hsync,  // 行同步（水平同步）信�?
    output wire       video_vsync,  // 场同步（垂直同步）信�?
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐�?
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked, clk_10M, clk_20M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设�?
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设�?
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出�?"1"表示时钟稳定�?
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，�? locked 信号转为后级电路的复�? reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  // 不使用内存�?�串口时，禁用其使能信号
  assign base_ram_ce_n = 1'b1;
  assign base_ram_oe_n = 1'b1;
  assign base_ram_we_n = 1'b1;

  assign ext_ram_ce_n = 1'b1;
  assign ext_ram_oe_n = 1'b1;
  assign ext_ram_we_n = 1'b1;

  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  // 数码管连接关系示意图，dpy1 同理
  // p=dpy0[0] // ---a---
  // c=dpy0[1] // |     |
  // d=dpy0[2] // f     b
  // e=dpy0[3] // |     |
  // b=dpy0[4] // ---g---
  // a=dpy0[5] // |     |
  // f=dpy0[6] // e     c
  // g=dpy0[7] // |     |
  //           // ---d---  p

  // 7 段数码管译码器演示，�? number �? 16 进制显示在数码管上面
  logic [7:0] number;
  assign number = 'b0;
  SEG7_LUT segL (
      .oSEG1(dpy0),
      .iDIG (number[3:0])
  );  // dpy0 是低位数码管
  SEG7_LUT segH (
      .oSEG1(dpy1),
      .iDIG (number[7:4])
  );  // dpy1 是高位数码管

  logic [15:0] led_bits;
  assign leds = led_bits;

  reg last_button_reg;
  reg button_reg;

  always_ff @(posedge clk_10M) begin
    if(reset_of_clk10M) begin
      last_button_reg <= 1'b0;
      button_reg <= 1'b0;
    end else begin
      if(push_btn) begin
        last_button_reg <= 1'b1;
        button_reg <= ~last_button_reg;
      end else begin
        last_button_reg <= 1'b0;
        button_reg <= 1'b0;
      end
    end
  end

  `define STATE_READ_1  2'h0
  `define STATE_READ_2  2'h1
  `define STATE_READ_OP 2'h2
  `define STATE_CALC    2'h3

  (* MARK_DEBUG = "TRUE" *) reg[1:0] state_reg;
  (* MARK_DEBUG = "TRUE" *) reg[31:0] operand1_reg;
  (* MARK_DEBUG = "TRUE" *) reg[31:0] operand2_reg;
  reg[2:0] op_reg;

  always_ff @(posedge clk_10M) begin
    if(reset_of_clk10M) begin
      state_reg <= `STATE_READ_1;
      operand1_reg <= 32'b0;
      operand2_reg <= 32'b0;
    end else if(button_reg) begin
      case(state_reg)
        `STATE_READ_1: begin
          operand1_reg <= dip_sw;
          state_reg <= `STATE_READ_2;
        end
        `STATE_READ_2: begin
          operand2_reg <= dip_sw;
          state_reg <= `STATE_READ_OP;
        end
        `STATE_READ_OP: begin
          op_reg <= dip_sw[2:0];
          state_reg <= `STATE_CALC;
        end
      endcase
    end
  end

  (* MARK_DEBUG = "TRUE" *) wire[63:0] mul_result;
  (* MARK_DEBUG = "TRUE" *) wire[63:0] div_result;
  (* MARK_DEBUG = "TRUE" *) wire[31:0] float_result;
  reg[7:0] float_op;

  ila_0 ila(
    .clk(clk_10M),
    .probe0(state_reg),
    .probe1(operand1_reg),
    .probe2(operand2_reg),
    .probe3(mul_result),
    .probe4(div_result),
    .probe5(float_result)
  );

  always_comb begin
    float_op = 8'b0;
    led_bits = 16'b0;
    case(op_reg)
      3'h0: begin
        led_bits = mul_result[15:0];
      end
      3'h1: begin
        led_bits = div_result[47:32];
      end
      3'h2: begin
        led_bits = div_result[15:0];
      end
      3'h3: begin
        led_bits = float_result[15:0];
      end
      3'h4: begin
        led_bits = float_result[15:0];
        float_op = 8'b1;
      end
    endcase
  end

  mult_gen_0 multiplier(
    .CLK(clk_10M),
    .SCLR(reset_of_clk10M),
    .A(operand1_reg),
    .B(operand2_reg),
    .P(mul_result)
  );

  div_gen_0 divider(
    .aclk(clk_10M),
    .aresetn(~reset_of_clk10M),
    .s_axis_divisor_tdata(operand2_reg),
    .s_axis_divisor_tvalid(1'b1),
    .s_axis_dividend_tdata(operand1_reg),
    .s_axis_dividend_tvalid(1'b1),
    .m_axis_dout_tdata(div_result),
    .m_axis_dout_tvalid()
  );

  floating_point_0 floating_point_add_sub(
    .aclk(clk_10M),
    .aresetn(~reset_of_clk10M),
    .s_axis_a_tdata(operand1_reg),
    .s_axis_a_tvalid(1'b1),
    .s_axis_b_tdata(operand2_reg),
    .s_axis_b_tvalid(1'b1),
    .s_axis_operation_tdata(float_op),
    .s_axis_operation_tvalid(1'b1),
    .m_axis_result_tdata(float_result),
    .m_axis_result_tvalid()
  );

endmodule
