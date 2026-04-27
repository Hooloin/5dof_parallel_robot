'*******************************************************ECAT总线初始化

GLOBAL CONST BUS_TYPE = 0                       '总线类型。可用于上位机区分当前总线类型

GLOBAL CONST MAX_AXISNUM = 16          '最大轴数

GLOBAL CONST Bus_Slot  = 0                           '槽位号0（单总线控制器缺省0）

GLOBAL CONST PUL_AxisStart = 0          '本地脉冲轴起始轴号

GLOBAL CONST PUL_AxisNum = 0         '本地脉冲轴轴数量

GLOBAL CONST Bus_AxisStart = 1           '总线轴起始轴号

GLOBAL CONST Bus_NodeNum = 5         '总线配置节点数量,用于判断实际检测到的从站数量是否一致

 

GLOBAL Bus_InitStatus                       '总线初始化完成状态

Bus_InitStatus = -1

GLOBAL  Bus_TotalAxisnum            '检查扫描的总轴数

 

delay(3000)                     '延时3S等待驱动器上电，不同驱动器自身上电时间不同，具体根据驱动器调整延时

 

?"总线通讯周期：",SERVO_PERIOD,"us"

Ecat_Init()                       '初始化ECAT总线 

 

WHILE (Bus_InitStatus = 0)

        Ecat_Init()

WEND

 

END

 

'***************************************ECAT总线初始***************************************

'初始流程：slot_scan（扫描总线） -> 从站节点映射轴/io  ->  SLOT_START（启动总线） -> 初始化成功

'********************************************************************************************

GLOBAL SUB Ecat_Init()

        LOCAL Node_Num,Temp_Axis,Drive_Vender,Drive_Device,Drive_Alias

        RAPIDSTOP(2)

        FOR i=0 TO MAX_AXISNUM - 1                                                                '初始化还原轴类型

                AXIS_ENABLE(i) = 0

                ATYPE(I)=0   

                AXIS_ADDRESS(i) =0

                DELAY(10)                                                     '防止所有驱动器全部同时切换使能导致瞬间电流过大

        NEXT

 

        Bus_InitStatus = -1

        Bus_TotalAxisnum = 0  

        SLOT_STOP(Bus_Slot)                         

        DELAY(200)

        SLOT_SCAN(Bus_Slot)                                                                                 '扫描总线

        IF RETURN THEN 

                ?"总线扫描成功","连接从站设备数："NODE_COUNT(Bus_Slot)

                IF NODE_COUNT(Bus_Slot) <> Bus_NodeNum THEN    '判断总线检测数量是否为实际接线数量

                         ?""   

                         ?"扫描节点数量与程序配置数量不一致!" ,"配置数量:"Bus_NodeNum,"检测数量："NODE_COUNT(Bus_Slot)

                         Bus_InitStatus = 0          '初始化失败。报警提示

                         RETURN

                ENDIF   

                

                '"开始映射轴号"

                FOR Node_Num=0 TO NODE_COUNT(Bus_Slot)-1                                  '遍历扫描到的所有从站节点

                         Drive_Vender = NODE_INFO(Bus_Slot,Node_Num,0)                                 '读取驱动器厂商

                         Drive_Device = NODE_INFO(Bus_Slot,Node_Num,1)                                 '读取设备编号

                         Drive_Alias = NODE_INFO(Bus_Slot,Node_Num,3)                                  '读取设备拨码ID

                         

                        IF NODE_AXIS_COUNT(Bus_Slot,Node_Num) <> 0  THEN              '判断当前节点是否有电机

                                 FOR j=0 TO NODE_AXIS_COUNT(Bus_Slot,Node_Num)-1         '根据节点带的电机数量循环配置轴参数(针对一拖多驱动器)

                                         IF Drive_Vender = $83 THEN

                                                 'Sub_SetPdo(Node_Num,Drive_Vender,Drive_Device)       '设定PDO参数

                                         ELSE                                       

                                                 Temp_Axis = Bus_AxisStart + Bus_TotalAxisnum        '轴号按NODE顺序分配

                                                 'Temp_Axis = Drive_Alias                                                      '轴号按驱动器设定的拨码分配（一拖多需要特殊处理）

                                                 BASE(Temp_Axis)

                                                 AXIS_ADDRESS= Bus_TotalAxisnum+1                             '映射轴号

                                                 ATYPE=65                                                                              '设置控制模式 65-位置 66-速度 67-转矩 

                                                 DRIVE_PROFILE = -1

                                                 'Sub_SetPdo(Node_Num,Drive_Vender,Drive_Device)               '设定PDO参数

                                                 'Sub_SetDriverIo(Drive_Vender,Temp_Axis,32 + 32*Temp_Axis)        '映射驱动器IO  IO映射到控制器IO32-以后每个驱动器间隔32点                       

                                                 'Sub_SetNodePara(Node_Num,Drive_Vender,Drive_Device,j)           '设置特殊总线参数

                                                 DISABLE_GROUP(Temp_Axis)                                                           '每轴单独分组

                                                 Bus_TotalAxisnum=Bus_TotalAxisnum+1                                           '总轴数+1

                                         ENDIF

                                 NEXT

                         ELSE                                                                                                                  'IO扩展模块

'                                Sub_SetNodeIo(Node_Num,Drive_Vender,Drive_Device,1024 + 32*Node_Num)              '映射扩展模块IO  

                         ENDIF

                NEXT

                ?"轴号映射完成","连接总轴数："Bus_TotalAxisnum

                

                DELAY 200

                SLOT_START(Bus_Slot)                              '启动总线

                IF RETURN THEN 

                         

                         WDOG=1                                                        '使能总开关

                         

                         '?"开始清除驱动器错误"

                         FOR i= Bus_AxisStart TO Bus_AxisStart + Bus_TotalAxisnum - 1 

                                 BASE(i)

                                 DRIVE_CLEAR(0)

                                 DELAY 50

        

                                 '?"驱动器错误清除完成"

                                 DATUM(0)                                             '清除控制器轴状态错误"

                                 DELAY 100   

                                 

                                 '"轴使能"

                                 AXIS_ENABLE=1

                         NEXT

                         Bus_InitStatus  = 1

                         ?"轴使能完成"

                         

                         '本地脉冲轴配置

                         FOR i = 0 TO PUL_AxisNum - 1

                                 BASE(PUL_AxisStart + i)

                                 AXIS_ADDRESS  = (-1<<16) + i

                                 ATYPE = 4

                         NEXT

                         ?"总线开启成功"                   

                ELSE

                         ?"总线开启失败"

                         Bus_InitStatus = 0

                ENDIF    

        ELSE

                ?"总线扫描失败"

                Bus_InitStatus = 0

        ENDIF

 

END SUB

 

'**************************************从站节点特殊参数配置********************************

'通过SDO方式修改对应对象字典的值修改从站参数(具体对象字典查看驱动器手册)

'******************************************************************************************

GLOBAL SUB Sub_SetNodePara(iNode,iVender,iDevice,Iaxis)

        IF     iVender = $41B AND iDevice = $1ab0 THEN            '正运动24088脉冲扩展轴

                SDO_WRITE(Bus_Slot,iNode,$6011,Iaxis*$800,5,4)                 '设置扩展脉冲轴ATYPE类型

                SDO_WRITE(Bus_Slot,iNode,$6012,Iaxis*$800,6,0)                 '设置扩展脉冲轴INVERT_STEP脉冲输出模式

                NODE_IO(Bus_Slot,iNode) = 32 + 32*iNode                              '设置240808上IO的起始映射地址

        ELSEIF iVender = $66f THEN                                                       '松下驱动器

                SDO_WRITE(Bus_Slot,iNode,$3401,0,4,$10101)                               '正限位电平 $818181

                SDO_WRITE(Bus_Slot,iNode,$3402,0,4,$20202)                               '负限位电平 $828282

                

                SDO_WRITE(Bus_Slot,iNode,$6091,1,7,1)                                         '齿轮比

                SDO_WRITE(Bus_Slot,iNode,$6091,2,7,1) 

                SDO_WRITE(Bus_Slot,iNode,$6092,1,7,10000)                                 '电机一圈脉冲数

                SDO_WRITE(Bus_Slot,iNode,$607E,0,5,224)                                     '电机方向0  反转224         

                SDO_WRITE(Bus_Slot,iNode,$6085,0,7,4290000000)                       '异常减速度

                'SDO_WRITE(Bus_Slot,iNode,$1010,1,7,$65766173)                        '写EPPROM(写EPPROM后驱动器需要重新上电)         

        ELSEIF iVender = $100000 THEN                                                '汇川驱动器

                SDO_WRITE(Bus_Slot,iNode,$6091,1,7,1)                                         '齿轮比

                SDO_WRITE(Bus_Slot,iNode,$6091,2,7,1) 

        ENDIF

END SUB

 

'***************************************总线驱动IO映射**************************************

'通过DRIVE_IO指令映射驱动器对象字典中60FD,60FE输入输出状态，要设置正确的DRIVE_PROFILEE或者POD后才可以正常映射

'DRIVE_PROFILE模式包含60FD/60FE

'iAxis - 轴号  iVender - 驱动器类型  i_IoNum - 输入输出起始编号

'********************************************************************************************

GLOBAL SUB Sub_SetDriverIo(iVender,Iaxis,i_IoNum)

        IF     iVender = $66f THEN            '松下驱动器

                DRIVE_PROFILE(iAxis) = 5                        '设定对应的带IO映射的PDO模式

                DRIVE_IO(iAxis) = i_IoNum

                

                REV_IN(iAxis) = i_IoNum                            '负限位应60FD BIT0

                FWD_IN(iAxis) = i_IoNum + 1                     '正限位先对应60FD BIT1

                DATUM_IN(iAxis) = i_IoNum + 2                       '原点先对应60FD BIT2

                

                INVERT_IN(i_IoNum,ON)                           '特殊信号有效电平反转

                INVERT_IN(i_IoNum + 1,ON)

                INVERT_IN(i_IoNum + 2,ON)

        ELSE

                DRIVE_PROFILE(iAxis) = 12                      '不带转矩获取的模式,总线步进驱动器IO可以使用

                DRIVE_IO(iAxis) = i_IoNum

                

                REV_IN(iAxis) = i_IoNum                            

                FWD_IN(iAxis) = i_IoNum + 1                     

                DATUM_IN(iAxis) = i_IoNum + 2                       

                

                INVERT_IN(i_IoNum,ON)                                    

                INVERT_IN(i_IoNum + 1,ON)

                INVERT_IN(i_IoNum + 2,ON)     

        ENDIF

 

END SUB

 

'***************************************总线IO模块映射**************************************

'通过NODE_IO(Bus_Slot,Node_Num)分配模块IO起始地址

'*******************************************************************************************

GLOBAL SUB Sub_SetNodeIo(iNode,iVender,iDevice,i_IoNum)

        IF     iVender = $41B AND iDevice = $130  THEN            '正运动EIO1616

                NODE_IO(Bus_Slot,iNode) = i_IoNum

        ENDIF

 

END SUB

 

'***************************************总线驱动器回零**************************************

'驱动器回零

'*******************************************************************************************

GLOBAL SUB Sub_SetDriverHome(iAxis,Imode)

 

        TRIGGER

        LOCAL home_sp1,home_sp2,home_mode,home_offset,home_acc

        home_sp1 = 10000

        home_sp2 = 10000

        home_acc = 1000000

        home_mode = Imode

        home_offset  = 0

        

        BASE(iAxis)

        UNITS = 1000

        AXIS_STOPREASON = 0

        DATUM(21,Imode)

        WAIT IDLE

        IF AXIS_STOPREASON = 0 THEN

                ?"回零成功"

        ELSE

                ?"回零失败"   ,"停止原因：",AXIS_STOPREASON,"状态字0X",HEX(DRIVE_STATUS)

        ENDIF

 

END SUB

