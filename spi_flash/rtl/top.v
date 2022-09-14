module top(
    input               clk     ,
    input               rst_n   ,
    
    input               miso    ,
    output              mosi    ,
    output              sclk    ,
    output              cs_n    ,

    input       [2:0]   key_in  ,
    output      [5:0]   seg_sel ,
    output      [7:0]   seg_dig 
    );

//中间信号定义
    wire    [2:0]   key_out     ;
    reg     [7:0]   wr_data     ;
    wire            trans_req   ;
    wire    [7:0]   tx_data     ;
    wire    [7:0]   rx_data     ;
    wire            trans_done  ;
    wire    [47:0]  dout        ;
    wire    [5:0]   dout_mask   ;
    wire            dout_vld    ;
    wire            locked      ;
    wire            clk_sample  ;

//模块例化

    pll u_pll(
	.areset (~rst_n     ),
	.inclk0 (clk        ),
	.c0     (clk_sample ),
	.locked (locked     )
    );


    key_debounce #(.KEY_W(3)) u_key(
	/*input					*/.clk		(clk        ),
	/*input					*/.rst_n	(rst_n      ),
	/*input		[KEY_W-1:0]	*/.key_in 	(key_in     ),
	/*output	[KEY_W-1:0]	*/.key_out	(key_out    ) 
    );

    flash_ctrl u_ctrl(
    /*input               */.clk         (clk       ),
    /*input               */.rst_n       (rst_n     ),
    /*input   [2:0]       */.key         (key_out   ),
    /*input   [ 7:0]      */.wr_din      (wr_data   ),//写入的数据
    /*input   [23:0]      */.rw_addr     (24'h0f9103),//flash读写地址
    /*output              */.trans_req   (trans_req ),
    /*output  [7:0]       */.tx_dout     (tx_data   ),
    /*input   [7:0]       */.rx_din      (rx_data   ),
    /*input               */.trans_done  (trans_done),
    /*output  [47:0]      */.dout        (dout      ),
    /*output  [5:0]       */.dout_mask   (dout_mask ),
    /*output              */.dout_vld    (dout_vld  ) 
    );

    spi_master u_spi(
    /*input           */.clk     (clk       ),
    /*input           */.rst_n   (rst_n     ),
    /*input           */.req     (trans_req ),
    /*input   [7:0]   */.din     (tx_data   ),
    /*output  [7:0]   */.dout    (rx_data   ),
    /*output          */.done    (trans_done),
    /*output          */.cs_n    (cs_n      ),
    /*output          */.mosi    (mosi      ),
    /*input           */.miso    (miso      ),
    /*output          */.sclk    (sclk      )         
    );

    seg_driver u_seg(
    /*input           */.clk     (clk       ),
    /*input           */.rst_n   (rst_n     ),
    /*input   [47:0]  */.din     (dout      ),
    /*input           */.din_vld (dout_vld  ),
    /*input   [5:0]   */.din_mask(dout_mask ),
    /*output  [5:0]   */.sel     (seg_sel   ),//片选信号
    /*output  [7:0]   */.dig     (seg_dig   ) //段选信号
    );

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            wr_data <= 0;
        end
        else if(key_out[2])begin
            wr_data <= wr_data + 1;
        end
    end

endmodule

