% Mainline_Setup.m - a script which is called by all mainlines to eprform
% the initialisation of the section and then to determine which buffering
% case is present and call the appropriate Main_Buffer_X script.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%SENSOR SHARING VERSION%%%%%%%%%%%%
%% Initialisation Section
disp('Performing Mainline Setup')
%Read config file for NXT id
fid = fopen(path2master,'rt');
%Scan within file for text with certain formatting
out = textscan(fid,'%s	%s');
%Close file
fclose(fid);
Failure_Flag = 0; 
error_type = 'none';
fault_flag =0;
fault_matrix = []; 
tic;
%Finds correct label within read data from config file by matching string
%to identify NXT
ind = strmatch(strcat('Main',num2str(Main_id)), out{1});

%Reads corresponding NXT Mac address into variable Code
Code = [out{2}(ind)]

% Establish connection with the NXT brick
OpenLink;

% Read maximum buffer size from the config file
disp('Reading Config File for Running Setup')
%Open config file
fid = fopen(path2config,'rt');
%Scan within file for text with certain formatting
out = textscan(fid,'%s	%s	%s	%s %s');
%Close file
fclose(fid);

%section to read the speed for the mainline from file 
fid = fopen(path2master,'rt');
out2 = textscan(fid,'%s %s %s');
fclose(fid);

speed_ind= strmatch('SPEED_M',out2{1});
speed = out2{3}(speed_ind);
speed = str2num(speed{1});
disp(['The Running Speed is ' num2str(speed)])

%Search for 'LineN' and put values into array ind
ind = strmatch(strcat('Line',num2str(Main_id)), out{1});
if length(ind) > 1
     ind=ind(1);
end 
Buffer_num = out{5}(ind);
disp(['The Buffer State is ' Buffer_num])
Buffer_num = str2num(Buffer_num{1});

%% Setup Running Variables
disp('Setting up Running Variables')
toc

% section to declare teh step size variables
dist=700;
dist2=1800; 

%run the first time sensor setup routine
first_run =1;
%initially no pallets on the mainline, this varibale keeps track of the
%number of pallets on the mainline 
no_pallets_mainline=0;
No_pallets_mainline2=0;
handshake_flag =0; % flag to show that a pallet is currently under the sensor and so will appear in both counts; 

% New section to track the amount of data read/written 2/11/12
sensor_data_read_amount =0;
sensor_data_write_amount =0;
messages_data_read_amount =0;
messages_data_write_amount =0;

% section to declare variables which give the motor running time
time_on_1=0;  %last start time of the motor for the single belt 
time_off_1 =0;%last stop time of the motor for the single belt 
time_off_2=0; %last stop time of the motor for the single belt 
time_on_2=0;  %last start time of the motor for the single belt 
time_running_1=0; 
time_running_2=0; 

%flags to show the previous status from the sensors
entering_previous_pallet=0;
exiting_previous_pallet=0;
transfer_previous_pallet=0; 
enteringflag=0;
exitingflag=0;
exitingflag2=0;

Running_1=0;
Running_2=0;
time_in =[]; 
t2 =0;
blockage = 0; 
pallet = 0; 
time_last_exit = 0;

% code to point to where to store the data matrix for the entering data 
filename_entval = ['Entval_matrix',num2str(Main_id),'.mat'];
filepath_entval = [path2sensordata,filename_entval];

% new code to find the shared sensors 12/10/12
filename_Mval_main = ['Mval_Current',num2str(Main_id),'.txt'];
filepath_Mval_main = [path2databus,filename_Mval_main]; 
filename_Platformstatus_main =['Platform_Sensor_Data_Current_',num2str(Main_id),'.txt'];
filepath_Platformstatus_main=[path2databus,filename_Platformstatus_main];
Ent_matrix=[];
entering_previous_pallet=0;
transfer_previous_pallet=0; 
armcheck =0; %variable to track the number of sighting of pallet- 1 sighting is the arm retracting 2 sightings indicates a static pallet
blockage = 0;

transfer_state =1; 
transfer_state_belt1=1;
transfer_state_belt2=1;
%running_1 flag detects whether the run command has been sent to the motor
%singlebelton keeps the data from the motor to show if the command has been
%initiated by the motor yet, the same is true of the double belt flags 
time_in_last = 0; % variable to keep track of time of last entering pallet
time_out_last =0; 
time_on_single = 0;
time_on_double = 0;
delay_startup_time =0.2;


% new code to find the sahred sensors 12/10/12
filename_Platformstatus_main_light =['Tval_Current',num2str(Main_id),'.txt'];
filepath_Platformstatus_main_light =[path2databus,filename_Platformstatus_main_light];

disp('Finished Setting Up Running variables')
toc 

%% Physical Initialisation
disp('Initiating Physical Initialisations')
toc 
% initialise two light sensors and one touch sensor 
disp('Initialising Sensors')
OpenLight(SENSOR_1, 'ACTIVE',Main);
%OpenLight(SENSOR_2, 'ACTIVE',Main);
OpenSwitch(SENSOR_3, Main); 
OpenLight(SENSOR_4, 'ACTIVE',Main);

% Section of code to purge the mainline
disp('Purging The Conveyor')
conveyor_purgeA = NXTMotor('A','Power',100,'TachoLimit', (10000) ,'ActionAtTachoLimit','Brake','SmoothStart',true);
conveyor_purgeB = NXTMotor('B','Power',-100,'TachoLimit', (10000) ,'ActionAtTachoLimit','Brake','SmoothStart',true);
conveyor_purgeA.SendToNXT(Main);
conveyor_purgeB.SendToNXT(Main);

disp('Completed Physical Initialisations')
toc 


%% Setup Motor Commands
disp('Beginning to Set Up Motor Commands')
toc 

% define the two separate motor sections
conveyor_1_GO = NXTMotor('B','Power',-1*speed);
conveyor_2_GO = NXTMotor('A','Power',speed);
conveyor_1_STOP = NXTMotor('B','Power',0);
conveyor_2_STOP = NXTMotor('A','Power',0);

conveyor_1_handover_stop = NXTMotor('B','Power',(-1*speed),'TachoLimit', 580 ,'ActionAtTachoLimit','Brake','SmoothStart',true);
conveyor_1_step  = NXTMotor('B','Power',(-1*speed),'TachoLimit', dist ,'ActionAtTachoLimit','Brake','SmoothStart',true);%step crate forward 1 step (newer alternative to move)
conveyor_1_step2 = NXTMotor('B','Power',(-1*speed),'TachoLimit', (dist*2) ,'ActionAtTachoLimit','Brake','SmoothStart',true); %step crate forward 2 step (newer alternative to move) step (newer alternative to move)
conveyor_2_step  = NXTMotor('A','Power',speed,'TachoLimit', dist2 ,'ActionAtTachoLimit','Brake','SmoothStart',true); %step crate forward 1 step
conveyor_2_unload =NXTMotor('A','Power',speed,'TachoLimit', 820 ,'ActionAtTachoLimit','Brake','SmoothStart',true); %small step to push it off the edge

disp('Completed Setting Up Motor Commands')
toc 

%if go file does not exist wait at this loop until go file does exist
disp('Waiting to Go')
toc
disp('-------------------------------------------------------------------')
Go = exist (path2go);
while Go == 0
	Go = exist (path2go);
	pause (0.2);
end

%% Operations Section 
tic;
disp('Process Started')
Time_started_Program = toc; 
if Buffer_num == 0
    Main_Buffer_0_alt;
end

if Buffer_num == 1
    Main_Buffer_1;
end

if Buffer_num == 2
    Main_Buffer_2;
end

if Buffer_num == 3
    Main_Buffer_3;
end

%% If the Buffer Number is 100, simply run the mainline continously 
if Buffer_num == 100
    disp('Running the Mainline Continuously')
    % %Assign motor
    firstConveyor = NXTMotor('A');
    secondConveyor = NXTMotor('B');

    % %Motor command values (insert control here!)
    firstConveyor.Power = 1*speed;
    secondConveyor.Power = -1*speed;

    % %Send command to activate
    firstConveyor.SendToNXT(Main);
    secondConveyor.SendToNXT(Main);
    time_on_1= toc; 
    % % run until Go is not equal to two, then proceed to the stop motor part of
    state = [2 2];

    Go = exist (path2go);
    while Go == 2
        Go = exist (path2go);
        fault_matrix = [fault_matrix;toc,0];
        pause (0.2);
     end

    firstConveyor.Stop('off', Main)
    secondConveyor.Stop('off', Main)
    time_off_1 = toc; 
    time_running_1 = 2 * (time_off_1 - time_on_1);
    disp('The total motor running time is (in seconds)')
    disp(time_running_1)
end

Time_Finished_Program = toc; 


%% Shutdown Section
% shutdown routine to stop all motors, turn off all sensors and shutdown
% the line/conenction to NXT.
% record the faulkt matrix into its location for later analysis 
path2faultmatrix = [path2failuredata,['Main_',num2str(Main_id),'_Failure_Matrix.mat']];
save(path2faultmatrix,'fault_matrix')

% find the total number of pallets remaining on this section of mainline
% for use in the experiment mode and save it to a file such that it can be
% retireved later. 
total_remaining = no_pallets_mainline + No_pallets_mainline2 - handshake_flag; 
filename_experidata=['main_',num2str(Main_id),'_results.mat'];
filepath_experidata=[path2experimentresults filename_experidata];
save(filepath_experidata,'total_remaining');
% jsut in case these have changed we reset them 
messages_data_write_amount=0;
messages_data_read_amount=0;
% display the data bus suage statistics for comparison. 
disp(['The Total Sensor data Read was ',num2str(sensor_data_read_amount),' bytes'])
disp(['The Total Sensor data Written was ',num2str(sensor_data_write_amount),' bytes'])
disp(['The Total Message data Read was ',num2str(messages_data_read_amount),' bytes'])
disp(['The Total Message data Written was ',num2str(messages_data_write_amount),' bytes'])
disp(['In ',num2str((Time_Finished_Program-Time_started_Program)),' seconds'])

% if this unit is the one that failed then we can replace the rror type
% file with its error report. 
if Failure_Flag == 1
    delete(path2errorlog)
    ffeedid=fopen(path2errorlog,'w');
    fprintf(ffeedid,'The Error Occured on Mainline_Unit ');
    fprintf(ffeedid,num2str(Main_id));
    fprintf(ffeedid,'\n');
    fprintf(ffeedid,'The Error Was: ');
    fprintf(ffeedid,error_type);
    fclose(ffeedid);
end
% close sown all the ensors and motors at the end of the run, terminate the
% NXT connection and then quit the instance of matlab. 
COM_SetDefaultNXT(Main);
StopMotor('all', false);
disp('stopped motors')
CloseSensor(SENSOR_1)
CloseSensor(SENSOR_2)
CloseSensor(SENSOR_3)
CloseSensor(SENSOR_4)
disp('Closed All Sensors')
COM_CloseNXT('all') %Close connection to NXT
quit % close this instance of matlab