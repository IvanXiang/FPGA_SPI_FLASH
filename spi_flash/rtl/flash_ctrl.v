module flash_ctrl(

    input               clk         ,
    input               rst_n       ,
    
    input   [2:0]       key         ,
    input   [ 7:0]      wr_din      ,//写入的数据
    input   [23:0]      rw_addr     ,//flash读写地址
    
    output              trans_req   ,
    output  [7:0]       tx_dout     ,
    input   [7:0]       rx_din      ,
    input               trans_done  ,

    output  [47:0]      dout        ,
    output  [5:0]       dout_mask   ,
    output              dout_vld     

);

//信号定义
    
    wire                 wr_req         ; 
    wire     [7:0]       wr_dout        ; 

    wire     [47:0]      wr_data        ;
    wire     [5:0]       wr_data_mask   ;
    wire                 wr_data_vld    ;

    wire                 rd_req         ; 
    wire     [7:0]       rd_dout        ; 
 
    wire     [47:0]      rd_data        ;
    wire     [5:0]       rd_data_mask   ;
    wire                 rd_data_vld    ;

//模块例化
flash_write u_write(
    /*input               */.clk         (clk           ),
    /*input               */.rst_n       (rst_n         ),
    /*input               */.write       (key[2]        ),
    /*input   [ 7:0]      */.wr_data     (wr_din        ),//写入的数据
    /*input   [23:0]      */.wr_addr     (rw_addr       ),//flash写地址
    /*output              */.trans_req   (wr_req        ),
    /*output  [7:0]       */.tx_dout     (wr_dout       ),
    /*input   [7:0]       */.rx_din      (rx_din        ),
    /*input               */.trans_done  (trans_done    ),
    /*output  [47:0]      */.dout        (wr_data       ),
    /*output  [5:0]       */.dout_mask   (wr_data_mask  ),
    /*output              */.dout_vld    (wr_data_vld   )
);
 flash_read u_read(
    /*input               */.clk         (clk           ),
    /*input               */.rst_n       (rst_n         ),
    /*input               */.rd_id       (key[0]        ),
    /*input               */.rd_data     (key[1]        ),
    /*input   [23:0]      */.rd_addr     (rw_addr       ),//flash读地址
    /*output              */.trans_req   (rd_req        ),
    /*output  [7:0]       */.tx_dout     (rd_dout       ),
    /*input   [7:0]       */.rx_din      (rx_din        ),
    /*input               */.trans_done  (trans_done    ),
    /*output  [47:0]      */.dout        (rd_data       ),
    /*output  [5:0]       */.dout_mask   (rd_data_mask  ),
    /*output              */.dout_vld    (rd_data_vld   )
);

    assign trans_req = rd_req | wr_req;
    assign tx_dout = {8{wr_req}} & wr_dout | {8{rd_req}} & rd_dout;
    assign dout_vld = wr_data_vld | rd_data_vld;
    assign dout = {48{wr_data_vld}} & wr_data 
                | {48{rd_data_vld}} & rd_data;
    assign dout_mask = {6{wr_data_vld}} & wr_data_mask
                     | {6{rd_data_vld}} & rd_data_mask;
endmodule 

