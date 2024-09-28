`default_nettype none
`timescale 1 ns / 1 ps

module aqp_esp_spi(
    input  wire        clk,
    input  wire        reset,

    // Bus master interface
    input  wire        ebus_phi,

    output reg  [15:0] spibm_a,
    input  wire  [7:0] spibm_rddata,
    output reg   [7:0] spibm_wrdata,
    output reg         spibm_wrdata_en,
    output reg         spibm_rd_n,
    output reg         spibm_wr_n,
    output reg         spibm_mreq_n,
    output reg         spibm_iorq_n,
    output wire        spibm_busreq,

    // Interface for core specific messages
    output wire        spi_msg_end,
    output wire  [7:0] spi_cmd,
    output wire [63:0] spi_rxdata,

    // Display overlay interface
    // output wire   [9:0] ovl_text_addr,
    // output wire  [15:0] ovl_text_wrdata,
    // output wire         ovl_text_wr,

    // output wire  [10:0] ovl_font_addr,
    // output wire   [7:0] ovl_font_wrdata,
    // output wire         ovl_font_wr,

    // output wire   [3:0] ovl_palette_addr,
    // output wire  [15:0] ovl_palette_wrdata,
    // output wire         ovl_palette_wr,

    // ESP SPI slave interface
    input  wire        esp_ssel_n,
    input  wire        esp_sclk,
    input  wire        esp_mosi,
    output wire        esp_miso,
    output wire        esp_notify
);

    assign esp_notify = 1'b0;

    //////////////////////////////////////////////////////////////////////////
    // SPI slave
    //////////////////////////////////////////////////////////////////////////
    wire        msg_start, msg_end, rxdata_valid;
    wire  [7:0] rxdata;
    reg   [7:0] q_txdata = 0;
    wire        txdata_ack;

    aqp_spislave spislave(
        .clk(clk),

        .esp_ssel_n(esp_ssel_n),
        .esp_sclk(esp_sclk),
        .esp_mosi(esp_mosi),
        .esp_miso(esp_miso),
        
        .msg_start(msg_start),
        .msg_end(msg_end),
        .rxdata(rxdata),
        .rxdata_valid(rxdata_valid),
        .txdata(q_txdata),
        .txdata_ack(txdata_ack));

    //////////////////////////////////////////////////////////////////////////
    // Data reception
    //////////////////////////////////////////////////////////////////////////
    reg [63:0] q_data;

    localparam [1:0]
        StIdle = 2'b00,
        StCmd  = 2'b01,
        StData = 2'b10;

    reg [1:0] q_state = StIdle;
    reg [7:0] q_cmd;
    reg [2:0] q_byte_cnt;

    always @(posedge clk) begin
        if (msg_start)
            q_state <= StCmd;
        if (msg_end)
            q_state <= StIdle;
        if (msg_start || msg_end)
            q_byte_cnt <= 3'b0;
        if (rxdata_valid)
            q_byte_cnt <= q_byte_cnt + 3'b1;

        if (q_state == StCmd && rxdata_valid) begin
            q_cmd   <= rxdata;
            q_state <= StData;
        end

        if (q_state == StData && rxdata_valid) begin
            q_data <= {rxdata, q_data[63:8]};
        end
    end

    assign spi_msg_end = msg_end;
    assign spi_cmd     = q_cmd;
    assign spi_rxdata  = q_data;

    //////////////////////////////////////////////////////////////////////////
    // Commands
    //////////////////////////////////////////////////////////////////////////
    reg q_phi;
    always @(posedge clk) q_phi <= ebus_phi;
    wire phi_falling =  q_phi && !ebus_phi;
    wire phi_rising  = !q_phi &&  ebus_phi;

    reg q_busreq = 1'b0;
    assign spibm_busreq = q_busreq;

    localparam [7:0]
        // CMD_RESET           = 8'h01,
        // CMD_SET_KEYB_MATRIX = 8'h10,
        // CMD_SET_HCTRL       = 8'h11,
        // CMD_WRITE_KBBUF     = 8'h12,
        CMD_BUS_ACQUIRE     = 8'h20,
        CMD_BUS_RELEASE     = 8'h21,
        CMD_MEM_WRITE       = 8'h22,
        CMD_MEM_READ        = 8'h23,
        CMD_IO_WRITE        = 8'h24,
        CMD_IO_READ         = 8'h25;
        // CMD_ROM_WRITE       = 8'h30,
        // CMD_SET_VIDMODE     = 8'h40;

    // 20h/21h: Acquire/release bus
    always @(posedge clk) begin
        if (phi_falling) begin
            if (q_cmd == CMD_BUS_ACQUIRE) q_busreq <= 1'b1;
            if (q_cmd == CMD_BUS_RELEASE) q_busreq <= 1'b0;
        end
    end

    localparam
        BStIdle   = 3'd0,
        BStCycle0 = 3'd1,
        BStCycle1 = 3'd2,
        BStCycle2 = 3'd3,
        BStDone   = 3'd4;

    reg [2:0] q_bus_state = BStIdle;

    always @(posedge clk) begin
        case (q_bus_state)
            BStIdle: begin
                spibm_rd_n      <= 1'b1;
                spibm_wr_n      <= 1'b1;
                spibm_mreq_n    <= 1'b1;
                spibm_iorq_n    <= 1'b1;
                spibm_wrdata_en <= 1'b0;

                if (rxdata_valid) begin
                    case (q_byte_cnt)
                        3'd1: spibm_a[7:0] <= rxdata;
                        3'd2: begin
                            spibm_a[15:8] <= rxdata;
                            if (q_cmd == CMD_MEM_READ || q_cmd == CMD_IO_READ) q_bus_state <= BStCycle0;
                        end
                        3'd3: begin
                            spibm_wrdata <= rxdata;
                            if (q_cmd == CMD_MEM_WRITE || q_cmd == CMD_IO_WRITE) q_bus_state <= BStCycle0;
                        end

                        default: begin end
                    endcase
                end
            end

            BStCycle0: begin
                if (phi_falling) begin
                    spibm_mreq_n    <= !(q_cmd == CMD_MEM_READ  || q_cmd == CMD_MEM_WRITE);
                    spibm_iorq_n    <= !(q_cmd == CMD_IO_READ   || q_cmd == CMD_IO_WRITE);
                    spibm_rd_n      <= !(q_cmd == CMD_MEM_READ  || q_cmd == CMD_IO_READ);
                    spibm_wrdata_en <=  (q_cmd == CMD_MEM_WRITE || q_cmd == CMD_IO_WRITE);
                    
                    q_bus_state <= BStCycle1;
                end
            end

            BStCycle1: begin
                if (phi_falling) begin
                    spibm_wr_n <= !(q_cmd == CMD_MEM_WRITE || q_cmd == CMD_IO_WRITE);

                    q_bus_state <= BStCycle2;
                end
            end

            BStCycle2: begin
                if (phi_falling) begin
                    if (q_cmd == CMD_MEM_READ || q_cmd == CMD_IO_READ)
                        q_txdata <= spibm_rddata;

                    spibm_mreq_n <= 1'b1;
                    spibm_iorq_n <= 1'b1;
                    spibm_rd_n   <= 1'b1;
                    spibm_wr_n   <= 1'b1;

                    q_bus_state <= BStDone;
                end
            end

            BStDone: begin
                if (phi_rising) begin
                    spibm_wrdata_en <= 1'b0;
                end
            end

            default: begin end

        endcase

        if (msg_start) q_bus_state <= BStIdle;
    end

endmodule
