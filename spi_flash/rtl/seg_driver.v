module seg_driver (
    input           clk     ,
    input           rst_n   ,
    input   [47:0]  din     ,
    input           din_vld ,
    input   [5:0]   din_mask,
    output  [5:0]   sel     ,//片选信号
    output  [7:0]   dig      //段选信号
);
    
    parameter TIME_SCAN = 25_000;//扫描间隔 5ms

    localparam  ZER   = 7'b100_0000,
                ONE   = 7'b111_1001,
                TWO   = 7'b010_0100,
                THR   = 7'b011_0000,
                FOU   = 7'b001_1001,
                FIV   = 7'b001_0010,
                SIX   = 7'b000_0010,
                SEV   = 7'b111_1000,
                EIG   = 7'b000_0000,
                NIN   = 7'b001_0000,
                NUM_A = 7'b000_1000,
                NUM_B = 7'b000_0011,
                NUM_C = 7'b100_0110,  
                NUM_D = 7'b010_0001,
                NUM_E = 7'b000_0110,  
                NUM_F = 7'b000_1110,
                R     = 7'b000_1000, 
                D     = 7'b010_0001, 
                P     = 7'b000_1100,
                N     = 7'b010_1011,
                S     = 7'b001_0010;

    reg     [19:0]  cnt_scan    ;//数码管扫描计数器
    wire            add_cnt_scan;
    wire            end_cnt_scan;

    reg     [47:0]  din_r       ;
    reg     [5:0]   mask_r      ;
    reg     [5:0]   seg_sel     ;
    reg     [7:0]   seg_dig     ;
    reg     [7:0]   disp_num    ;

    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            cnt_scan <= 0;
        end 
        else if(add_cnt_scan)begin 
            if(end_cnt_scan)begin 
                cnt_scan <= 0;
            end
            else begin 
                cnt_scan <= cnt_scan + 1;
            end 
        end
    end 
    assign add_cnt_scan = 1'b1;
    assign end_cnt_scan = add_cnt_scan && cnt_scan == TIME_SCAN-1;

    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            seg_sel <= 6'b111110;
        end 
        else if(end_cnt_scan)begin 
            seg_sel <= {seg_sel[4:0],seg_sel[5]};
        end 
    end

//disp_num
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            disp_num <= 0;
        end 
        else begin 
            case (seg_sel | mask_r)
                6'b01_1111:begin disp_num <= din_r[7:0]     ;end 
                6'b10_1111:begin disp_num <= din_r[15:8]    ;end 
                6'b11_0111:begin disp_num <= din_r[23:16]   ;end 
                6'b11_1011:begin disp_num <= din_r[31:24]   ;end 
                6'b11_1101:begin disp_num <= din_r[39:32]   ;end 
                6'b11_1110:begin disp_num <= din_r[47:40]   ;end 
                default  :begin disp_num <= 8'hFF          ;end 
            endcase
        end 
    end

//din_r din_vld
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            din_r <= 0;
            mask_r <= 0;
        end 
        else if(din_vld)begin 
            din_r <= din;
            mask_r <= din_mask;
        end 
    end

    //seg_dig
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            seg_dig <= 8'hff;
        end 
        else begin 
            case (disp_num)
                8'd0 :seg_dig <= {1'b1,ZER  };
                8'd1 :seg_dig <= {1'b1,ONE  };
                8'd2 :seg_dig <= {1'b1,TWO  };
                8'd3 :seg_dig <= {1'b1,THR  };
                8'd4 :seg_dig <= {1'b1,FOU  };
                8'd5 :seg_dig <= {1'b1,FIV  };
                8'd6 :seg_dig <= {1'b1,SIX  };
                8'd7 :seg_dig <= {1'b1,SEV  };
                8'd8 :seg_dig <= {1'b1,EIG  };
                8'd9 :seg_dig <= {1'b1,NIN  }; 
                8'd10:seg_dig <= {1'b1,NUM_A};
                8'd11:seg_dig <= {1'b1,NUM_B};
                8'd12:seg_dig <= {1'b1,NUM_C};
                8'd13:seg_dig <= {1'b1,NUM_D};
                8'd14:seg_dig <= {1'b1,NUM_E};
                8'd15:seg_dig <= {1'b1,NUM_F};
                "R"  :seg_dig <= {1'b1,R    };
                "D"  :seg_dig <= {1'b1,D    };
                "P"  :seg_dig <= {1'b1,P    };
                "N"  :seg_dig <= {1'b1,N    };
                "S"  :seg_dig <= {1'b1,S    };
                default:seg_dig <= 8'hff;
            endcase
        end 
    end

    assign dig = seg_dig;
    assign sel = seg_sel;

endmodule

