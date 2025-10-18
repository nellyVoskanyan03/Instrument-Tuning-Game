`include "config.svh"

module lab_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,

               screen_width  = 480,
               screen_height = 272,

               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,

               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height )
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,

    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,

    input        [         23:0] mic,
    output       [         15:0] sound,

    input                        uart_rx,
    output                       uart_tx,

    inout        [w_gpio  - 1:0] gpio
);

    assign sound   = '0;
    assign uart_tx = '1;

    logic [23:0] prev_mic;
    logic [19:0] counter;
    logic [19:0] distance;

    always_ff @ (posedge clk or posedge rst)
        if (rst) begin
            prev_mic <= '0;
            counter  <= '0;
            distance <= '0;
        end else begin
            prev_mic <= mic;
            if (prev_mic[$left(prev_mic)] == 1'b1 && mic[$left(mic)] == 1'b0) begin
                distance <= counter;
                counter  <= 20'h0;
            end else if (counter != ~20'h0) begin
                counter <= counter + 1;
            end
        end

    localparam freq_100_C = 26163,
               freq_100_D = 29366,
               freq_100_E = 32963,
               freq_100_F = 34923,
               freq_100_G = 39200,
               freq_100_A = 44000,
               freq_100_B = 49388;

    function [19:0] high_distance(input [18:0] freq_100);
        high_distance = clk_mhz * 1000 * 1000 / freq_100 * 103;
    endfunction

    function [19:0] low_distance(input [18:0] freq_100);
        low_distance = clk_mhz * 1000 * 1000 / freq_100 * 97;
    endfunction

    function [0:0] check_freq_single_range(input [18:0] freq_100, input [19:0] distance);
        check_freq_single_range = (distance > low_distance(freq_100)) && (distance < high_distance(freq_100));
    endfunction

    function [0:0] check_freq(input [18:0] freq_100, input [19:0] distance);
        check_freq = check_freq_single_range(freq_100 * 4, distance)
                  || check_freq_single_range(freq_100 * 2, distance)
                  || check_freq_single_range(freq_100, distance);
    endfunction


    wire check_C = check_freq(freq_100_C, distance);
    wire check_D = check_freq(freq_100_D, distance);
    wire check_E = check_freq(freq_100_E, distance);
    wire check_F = check_freq(freq_100_F, distance);
    wire check_G = check_freq(freq_100_G, distance);
    wire check_A = check_freq(freq_100_A, distance);
    wire check_B = check_freq(freq_100_B, distance);

    localparam w_note = 7;
    wire [w_note - 1:0] note = {check_C, check_D, check_E, check_F, check_G, check_A, check_B};

    logic [w_note-1:0] d_note;
    logic [w_note-1:0] t_note;
    logic [19:0] t_cnt;
    logic [w_note - 1:0] expected_note;

    localparam [w_note-1:0]
        no_note = 7'b0000000,
        C       = 7'b1000000,
        D       = 7'b0100000,
        E       = 7'b0010000,
        F       = 7'b0001000,
        G       = 7'b0000100,
        A       = 7'b0000010,
        B       = 7'b0000001;

    always_ff @ (posedge clk or posedge rst)
        if (rst) d_note <= no_note;
        else     d_note <= note;

    always_ff @ (posedge clk or posedge rst)
        if (rst) t_cnt <= 0;
        else     t_cnt <= (note == d_note) ? t_cnt + 1 : 0;

    always_ff @ (posedge clk or posedge rst)
        if (rst) t_note <= no_note;
        else if (&t_cnt) t_note <= d_note;

    logic pulse;

    strobe_gen #(.clk_mhz(27), .strobe_hz(30)) i_strobe_gen(clk, rst, pulse);


    // === FUNCTION: Move Toward Target Column ===
    function automatic [9:0] pass(
        input [9:0] current_x,
        input [9:0] current_y,
        input [9:0] nearest_stair_height,
        input [8:0] current_col,
        input [8:0] target_col,
        output [9:0] new_x,
        output [9:0] new_y
    );
        if(current_y < nearest_stair_height)
            new_y = current_y + 1;
        else if(current_y > nearest_stair_height)
            new_y = current_y - 1;
        else
            new_y = current_y;
        if (target_col > current_col && new_y == nearest_stair_height)
            new_x = current_x + 1;
        else
            new_x = current_x; // stay in place

    endfunction

    localparam PLAYER_WIDTH     = 16;
    localparam PLAYER_HEIGHT    = 16;
    localparam PLAYER_STEP      = 1;
    localparam int NUM_LEVELS   = 7;
    localparam int LEVEL_HEIGHT = screen_height / NUM_LEVELS;
    localparam int COLUMN_WIDTH = 60;
    localparam int COLUMN_THICKNESS = 10;
    localparam int GAP = 24;

    logic [9:0] player_x = 0;
    logic [9:0] player_y = 0;
    logic [8:0] column_index;
    logic [9:0] nearest_stair_height_from_right;
    logic [9:0] nearest_stair_height_from_left;
    logic vertical_blocked;
    logic horizontal_blocked;
    logic collision;
    logic [9:0] left_edge;
    logic [9:0] right_edge;
    logic [9:0] top_edge;
    logic [9:0] bottom_edge;

    always_ff @(posedge pulse or posedge rst) begin
        if (rst) begin
            player_x <= 11;
            player_y <= 0;
        end else begin
            logic [9:0] new_x = player_x;
            logic [9:0] new_y = player_y;

            if (key[0]) new_x = player_x + PLAYER_STEP;
            if (key[1]) new_x = player_x - PLAYER_STEP;
            if (key[2]) new_y = player_y + PLAYER_STEP;
            if (key[3]) new_y = player_y - PLAYER_STEP;

            column_index = player_x / COLUMN_WIDTH;
            case (column_index)
                0: expected_note <= C;
                1: expected_note <= D;
                2: expected_note <= E;
                3: expected_note <= F;
                4: expected_note <= G;
                5: expected_note <= A;
                6: expected_note <= B;
                default: expected_note <= no_note;
            endcase
            
            if (expected_note == t_note && expected_note != no_note) begin
               pass(player_x, player_y, column_index * LEVEL_HEIGHT, column_index, column_index + 1, new_x, new_y);
            end
            
            if (new_x + PLAYER_WIDTH > screen_width || new_x < 0)  new_x = player_x;
            if (new_y + PLAYER_HEIGHT > screen_height || new_y < 0) new_y = player_y;

            right_edge  = new_x % COLUMN_WIDTH;
            left_edge   = (new_x + PLAYER_WIDTH) % COLUMN_WIDTH;
            bottom_edge = new_y;
            top_edge    = new_y + PLAYER_HEIGHT;

            nearest_stair_height_from_right = (((new_x + PLAYER_WIDTH) / COLUMN_WIDTH) % NUM_LEVELS) * LEVEL_HEIGHT;
            nearest_stair_height_from_left = (((new_x - PLAYER_WIDTH) / COLUMN_WIDTH) % NUM_LEVELS) * LEVEL_HEIGHT;

            vertical_blocked   = (
                (top_edge > nearest_stair_height_from_right + GAP) ||
                (bottom_edge < nearest_stair_height_from_right)
             ) && new_y > player_y ||
             (
                (top_edge > nearest_stair_height_from_left + GAP) ||
                (bottom_edge < nearest_stair_height_from_left)
             );

            horizontal_blocked = (
                (left_edge > COLUMN_WIDTH - COLUMN_THICKNESS) ||
                (right_edge > COLUMN_WIDTH - COLUMN_THICKNESS && new_x < player_x)
            );

            collision          = vertical_blocked && horizontal_blocked;

            if (!collision) begin
                player_x <= new_x;
                player_y <= new_y;
            end
            led <= {7'b0, collision};
        end
    end

    logic player_pixel_on;
    assign player_pixel_on = (x >= player_x && x < player_x + PLAYER_WIDTH &&
                              y >= player_y && y < player_y + PLAYER_HEIGHT);

    logic column_pixel_on;
    logic [9:0] stair_height;

    always_comb begin
        stair_height = (((x / COLUMN_WIDTH)) % NUM_LEVELS) * LEVEL_HEIGHT;
        column_pixel_on = (((x % COLUMN_WIDTH) > COLUMN_WIDTH - COLUMN_THICKNESS && y < stair_height) ||
                           ((x % COLUMN_WIDTH) > COLUMN_WIDTH - COLUMN_THICKNESS && y > stair_height + GAP));
    end

    always_comb begin

        if (player_pixel_on) begin
            red   = 4'hFF;
            green = 4'h00;
            blue  = 4'h00;
        end else if (column_pixel_on) begin
            red   = 4'h00;
            green = 4'h00;
            blue  = 4'h00;
        end else begin
            red   = 4'hFF;
            green = 4'hFF;
            blue  = 4'hFF;
        end
        if(player_x == screen_width - PLAYER_WIDTH && player_y==0)
                green = 8'hFF;
        else
                green = 8'h00;
    end


    logic digit_sel;

    always_ff @(posedge clk or posedge rst)
        if (rst) digit_sel <= 0;
        else     digit_sel <= ~digit_sel;

    always_comb begin
        case (digit_sel)
            1'b0: begin
                case (expected_note)
                    C: abcdefgh <= 8'b10011100;
                    D: abcdefgh <= 8'b01111010;
                    E: abcdefgh <= 8'b10011110;
                    F: abcdefgh <= 8'b10001110;
                    G: abcdefgh <= 8'b10111100;
                    A: abcdefgh <= 8'b11101110;
                    B: abcdefgh <= 8'b00111110;
                    default: abcdefgh <= 8'b00000010;
                endcase
                digit = 8'b0000_0001;
            end
            1'b1: begin
                case (t_note)
                    C: abcdefgh <= 8'b10011100;
                    D: abcdefgh <= 8'b01111010;
                    E: abcdefgh <= 8'b10011110;
                    F: abcdefgh <= 8'b10001110;
                    G: abcdefgh <= 8'b10111100;
                    A: abcdefgh <= 8'b11101110;
                    B: abcdefgh <= 8'b00111110;
                    default: abcdefgh <= 8'b00000010;
                endcase
                digit = 8'b0000_0010;
            end
        endcase
    end

    
endmodule
