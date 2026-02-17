module control_fsm(
    // hit detector
    input logic wayIndex,
    input logic match,
    
    //status store
    input logic [1:0] st_bits0,
    input logic [1:0] st_bits1,
    input logic [1:0] st_bits2,
    input logic [1:0] st_bits3,
    output logic newControlState,
    output logic controlWriteEn,
    
    // plru store
    input logic [2:0] plru_state,
    output logic plruUpdate,
    output logic plruWriteEn

)



endmodule