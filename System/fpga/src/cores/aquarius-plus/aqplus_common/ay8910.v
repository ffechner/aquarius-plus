module ay8910(
    input  wire       clk,
    input  wire       reset,

    input  wire       a0,
    input  wire       wren,
    input  wire [7:0] wrdata,
    output reg  [7:0] rddata,

    input  wire [7:0] ioa_in_data,
    output wire [7:0] ioa_out_data,
    output wire       ioa_oe,

    input  wire [7:0] iob_in_data,
    output wire [7:0] iob_out_data,
    output wire       iob_oe,

    output wire [9:0] ch_a,
    output wire [9:0] ch_b,
    output wire [9:0] ch_c);

    //////////////////////////////////////////////////////////////////////////
    // Bus register interface
    //////////////////////////////////////////////////////////////////////////

    // Address latch
    reg [3:0] reg_addr_r;
    always @(posedge clk) if (wren && a0) reg_addr_r <= wrdata[3:0];

    // Bus registers
    reg [11:0] a_period_r,  b_period_r,  c_period_r;
    reg  [4:0] a_volume_r,  b_volume_r,  c_volume_r;
    reg        a_tone_n_r,  b_tone_n_r,  c_tone_n_r;
    reg        a_noise_n_r, b_noise_n_r, c_noise_n_r;
    reg        ioa_out_r,   iob_out_r;
    reg  [4:0] noise_period_r;
    reg [15:0] envelope_period_r;
    reg        envelope_hold_r, envelope_alternate_r, envelope_attack_r, envelope_continue_r;
    reg  [7:0] ioa_out_data_r, iob_out_data_r;

    assign ioa_out_data = ioa_out_data_r;
    assign ioa_oe       = ioa_out_r;
    assign iob_out_data = iob_out_data_r;
    assign iob_oe       = iob_out_r;

    wire eashape_wr = wren && !a0 && reg_addr_r == 4'hD;

    always @(posedge clk)
        if (reset) begin
            a_period_r           <= 12'b0;
            b_period_r           <= 12'b0;
            c_period_r           <= 12'b0;
            a_volume_r           <= 5'b0;
            b_volume_r           <= 5'b0;
            c_volume_r           <= 5'b0;
            a_tone_n_r           <= 1'b1;
            b_tone_n_r           <= 1'b1;
            c_tone_n_r           <= 1'b1;
            a_noise_n_r          <= 1'b1;
            b_noise_n_r          <= 1'b1;
            c_noise_n_r          <= 1'b1;
            ioa_out_r            <= 1'b0;
            iob_out_r            <= 1'b0;
            noise_period_r       <= 5'b0;
            envelope_period_r    <= 16'b0;
            envelope_hold_r      <= 1'b0;
            envelope_alternate_r <= 1'b0;
            envelope_attack_r    <= 1'b0;
            envelope_continue_r  <= 1'b0;
            ioa_out_data_r       <= 8'b0;
            iob_out_data_r       <= 8'b0;

        end else if (wren && !a0) begin
            case (reg_addr_r)
                4'h0: a_period_r[ 7:0]        <= wrdata;
                4'h1: a_period_r[11:8]        <= wrdata[3:0];
                4'h2: b_period_r[ 7:0]        <= wrdata;
                4'h3: b_period_r[11:8]        <= wrdata[3:0];
                4'h4: c_period_r[ 7:0]        <= wrdata;
                4'h5: c_period_r[11:8]        <= wrdata[3:0];
                4'h6: noise_period_r          <= wrdata[4:0];
                4'h7: { iob_out_r, ioa_out_r, c_noise_n_r, b_noise_n_r, a_noise_n_r, c_tone_n_r, b_tone_n_r, a_tone_n_r } <= wrdata;
                4'h8: a_volume_r              <= wrdata[4:0];
                4'h9: b_volume_r              <= wrdata[4:0];
                4'hA: c_volume_r              <= wrdata[4:0];
                4'hB: envelope_period_r[7:0]  <= wrdata;
                4'hC: envelope_period_r[15:8] <= wrdata;
                4'hD: { envelope_continue_r, envelope_attack_r, envelope_alternate_r, envelope_hold_r } <= wrdata[3:0];
                4'hE: ioa_out_data_r          <= wrdata;
                4'hF: iob_out_data_r          <= wrdata;
            endcase
        end

    always @*
        case (reg_addr_r)
            4'h0: rddata <= a_period_r[ 7:0];
            4'h1: rddata <= { 4'b0, a_period_r[11:8] };
            4'h2: rddata <= b_period_r[ 7:0];
            4'h3: rddata <= { 4'b0, b_period_r[11:8] };
            4'h4: rddata <= c_period_r[ 7:0];
            4'h5: rddata <= { 4'b0, c_period_r[11:8] };
            4'h6: rddata <= { 3'b0, noise_period_r };
            4'h7: rddata <= { iob_out_r, ioa_out_r, c_noise_n_r, b_noise_n_r, a_noise_n_r, c_tone_n_r, b_tone_n_r, a_tone_n_r };
            4'h8: rddata <= { 3'b0, a_volume_r };
            4'h9: rddata <= { 3'b0, b_volume_r };
            4'hA: rddata <= { 3'b0, c_volume_r };
            4'hB: rddata <= envelope_period_r[7:0];
            4'hC: rddata <= envelope_period_r[15:8];
            4'hD: rddata <= { envelope_continue_r, envelope_attack_r, envelope_alternate_r, envelope_hold_r };
            4'hE: rddata <= ioa_out_r ? ioa_out_data_r : ioa_in_data;
            4'hF: rddata <= iob_out_r ? iob_out_data_r : iob_in_data;
        endcase

    //////////////////////////////////////////////////////////////////////////
    // Clock divider (/128)
    //////////////////////////////////////////////////////////////////////////
    reg [6:0] div_r = 7'b0;
    always @(posedge clk) div_r <= div_r + 7'b1;
    wire tick = (div_r == 7'b0);

    //////////////////////////////////////////////////////////////////////////
    // Tone generators
    //////////////////////////////////////////////////////////////////////////
    reg [11:0] a_count_r,  b_count_r,  c_count_r;
    reg        a_output_r, b_output_r, c_output_r;

    always @(posedge clk)
        if (reset) begin
            a_count_r  <= 12'b0;
            b_count_r  <= 12'b0;
            c_count_r  <= 12'b0;
            a_output_r <= 12'b0;
            b_output_r <= 12'b0;
            c_output_r <= 12'b0;

        end else if (tick) begin
            // Channel A
            if (a_count_r >= a_period_r) begin
                a_output_r <= !a_output_r;
                a_count_r <= 4'd0;
            end else begin
                a_count_r <= a_count_r + 4'd1;
            end

            // Channel B
            if (b_count_r >= b_period_r) begin
                b_output_r <= !b_output_r;
                b_count_r <= 4'd0;
            end else begin
                b_count_r <= b_count_r + 4'd1;
            end

            // Channel C
            if (c_count_r >= c_period_r) begin
                c_output_r <= !c_output_r;
                c_count_r <= 4'd0;
            end else begin
                c_count_r <= c_count_r + 4'd1;
            end
        end

    //////////////////////////////////////////////////////////////////////////
    // Noise generator
    //////////////////////////////////////////////////////////////////////////
    reg  [4:0] noise_count_r;
    reg        prescale_noise_r;
    reg [16:0] lfsr_r;
    wire       noise_val = lfsr_r[0];

    always @(posedge clk)
        if (reset) begin
            noise_count_r    <= 5'd0;
            prescale_noise_r <= 1'b0;
            lfsr_r           <= 17'd1;

        end else if (tick) begin
            if (noise_count_r >= noise_period_r) begin
                noise_count_r <= 5'd0;
                prescale_noise_r <= !prescale_noise_r;
                if (prescale_noise_r) lfsr_r <= {lfsr_r[0] ^ lfsr_r[3], lfsr_r[16:1]};
            end else begin
                noise_count_r <= noise_count_r + 5'd1;
            end
        end

    //////////////////////////////////////////////////////////////////////////
    // Channel values
    //////////////////////////////////////////////////////////////////////////
    wire a_val = (a_output_r | a_tone_n_r) & (noise_val | a_noise_n_r);
    wire b_val = (b_output_r | b_tone_n_r) & (noise_val | b_noise_n_r);
    wire c_val = (c_output_r | c_tone_n_r) & (noise_val | c_noise_n_r);

    //////////////////////////////////////////////////////////////////////////
    // Envelope generator
    //////////////////////////////////////////////////////////////////////////

    // Period counter
    reg [16:0] envelope_period_cnt_r;
    wire       envelope_period_done = envelope_period_cnt_r >= {envelope_period_r, 1'b0};

    always @(posedge clk)
        if (reset)
            envelope_period_cnt_r <= 17'd0;
        else if (tick)
            envelope_period_cnt_r <= envelope_period_done ? 17'd0 : (envelope_period_cnt_r + 17'd1);

    // Envelope counter
    reg  [3:0] envelope_cnt_r;
    reg        envelope_updated_r;
    reg        envelope_cnt_up_r;
    reg  [3:0] envelope_volume_r;
    reg        envelope_stop_r;

    always @(posedge clk)
        if (reset) begin
            envelope_cnt_r     <= 4'd0;
            envelope_updated_r <= 1'b0;
            envelope_cnt_up_r  <= 1'b0;
            envelope_volume_r  <= 4'd0;
            envelope_stop_r    <= 1'b0;

        end else begin
            if (tick && envelope_period_done) begin
                if (!envelope_stop_r) begin
                    envelope_cnt_r <= envelope_cnt_r - 4'd1;

                    if (envelope_cnt_r == 4'd0) begin
                        if (!envelope_continue_r || envelope_hold_r) begin
                            envelope_cnt_r <= 4'd0;
                            envelope_stop_r <= 1'b1;
                        end

                        if (( envelope_continue_r && envelope_alternate_r) ||
                            (!envelope_continue_r && envelope_attack_r)) begin

                            envelope_cnt_up_r <= !envelope_cnt_up_r;
                        end
                    end
                end

                envelope_volume_r <= envelope_cnt_up_r ? (envelope_cnt_r ^ 4'hF) : envelope_cnt_r;

                if (envelope_updated_r) begin
                    envelope_updated_r <= 1'b0;
                    envelope_cnt_r     <= 4'd15;
                    envelope_cnt_up_r  <= envelope_attack_r;
                    envelope_stop_r    <= 1'b0;
                end
            end

            if (eashape_wr) begin
                envelope_updated_r <= 1'b1;
            end
        end

    //////////////////////////////////////////////////////////////////////////
    // Mixer
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] a_volume = a_val ? (a_volume_r[4] ? envelope_volume_r : a_volume_r[3:0]) : 4'd0;
    wire [3:0] b_volume = b_val ? (b_volume_r[4] ? envelope_volume_r : b_volume_r[3:0]) : 4'd0;
    wire [3:0] c_volume = c_val ? (c_volume_r[4] ? envelope_volume_r : c_volume_r[3:0]) : 4'd0;

    reg [9:0] ch_a_r = 10'd0;
    always @(posedge clk)
        if (tick) case (a_volume)
            4'h0: ch_a_r <= 0;
            4'h1: ch_a_r <= 6;
            4'h2: ch_a_r <= 9;
            4'h3: ch_a_r <= 13;
            4'h4: ch_a_r <= 19;
            4'h5: ch_a_r <= 27;
            4'h6: ch_a_r <= 39;
            4'h7: ch_a_r <= 56;
            4'h8: ch_a_r <= 80;
            4'h9: ch_a_r <= 116;
            4'hA: ch_a_r <= 166;
            4'hB: ch_a_r <= 239;
            4'hC: ch_a_r <= 344;
            4'hD: ch_a_r <= 495;
            4'hE: ch_a_r <= 712;
            4'hF: ch_a_r <= 1023;
        endcase

    reg [9:0] ch_b_r = 10'd0;
    always @(posedge clk)
        if (tick) case (b_volume)
            4'h0: ch_b_r <= 0;
            4'h1: ch_b_r <= 6;
            4'h2: ch_b_r <= 9;
            4'h3: ch_b_r <= 13;
            4'h4: ch_b_r <= 19;
            4'h5: ch_b_r <= 27;
            4'h6: ch_b_r <= 39;
            4'h7: ch_b_r <= 56;
            4'h8: ch_b_r <= 80;
            4'h9: ch_b_r <= 116;
            4'hA: ch_b_r <= 166;
            4'hB: ch_b_r <= 239;
            4'hC: ch_b_r <= 344;
            4'hD: ch_b_r <= 495;
            4'hE: ch_b_r <= 712;
            4'hF: ch_b_r <= 1023;
        endcase

    reg [9:0] ch_c_r = 10'd0;
    always @(posedge clk)
        if (tick) case (c_volume)
            4'h0: ch_c_r <= 0;
            4'h1: ch_c_r <= 6;
            4'h2: ch_c_r <= 9;
            4'h3: ch_c_r <= 13;
            4'h4: ch_c_r <= 19;
            4'h5: ch_c_r <= 27;
            4'h6: ch_c_r <= 39;
            4'h7: ch_c_r <= 56;
            4'h8: ch_c_r <= 80;
            4'h9: ch_c_r <= 116;
            4'hA: ch_c_r <= 166;
            4'hB: ch_c_r <= 239;
            4'hC: ch_c_r <= 344;
            4'hD: ch_c_r <= 495;
            4'hE: ch_c_r <= 712;
            4'hF: ch_c_r <= 1023;
        endcase

    assign ch_a = ch_a_r;
    assign ch_b = ch_b_r;
    assign ch_c = ch_c_r;

endmodule
