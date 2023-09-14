global num_target_gain_states num_target_phase_states Measurements Mapping Current_Calibration_Gain_Index Current_Calibration_Phase_Index target_gain_states ...
    target_phase_states  phase_error_criteria kernel_size target_phase_resolution ...
     lowest_detectable_gain_dB  target_gain_states_dB phase_error_history Selected_Measurements Current_Point_Iteration_Count original_kernel_size filter_tolerance Starting_Gain_Index Ending_Gain_Index...
    measurement_counter num_actual_vector_states num_actual_phase_states gain_profile max_gain_measurement max_target_gain ...
     phase_offset target_gain_states_dB_normalized actual_phase_resolution actual_phase_states min_target_gain total_measurement_counter kernel_offset theta1 theta2 rfvm_40GHz_table vector1_profile vector2_profile phase_reference...
     vector1_envelop_profile vector2_envelop_profile phase_error_sum gain_error_sum VALIDATION num_hit total_num_hit

%%
VALIDATION = 1;
num_hit = 0;
total_num_hit = 0;



%%
kernel_size = 1;
lowest_detectable_gain_dB = -8;

Starting_Gain_Index = 1;
Ending_Gain_Index = 12;

filter_tolerance = 1.2;


%%

load("rfvm_40GHz_table.mat");

theta1 = 0;
theta2 = pi/2;

%[L1, L2] = conversionClass.cartesian2vectors(-0.3-0.5i);

phase_reference = 0;

min_target_gain = 0;
max_target_gain = 0;

phase_error_sum = 0;
gain_error_sum = 0;

vector1_profile = zeros(20, 2);
vector2_profile = zeros(20, 2);

vector1_envelop_profile = zeros(20, 4);
vector2_envelop_profile = zeros(20, 4);

max_gain_measurement = zeros(num_actual_phase_states, 1);
max_target_gain = 0;

phase_offset = 0;
kernel_offset = 0;

num_target_gain_states = 12;
num_target_phase_states = 64;

num_actual_vector_states = 64;
%num_actual_phase_states = 256;

target_phase_resolution = 2*pi/num_target_phase_states;
actual_phase_resolution = 2*pi/180;

phase_error_history = zeros(2, 2);

%phase_error_criteria = actual_phase_resolution;


original_kernel_size = kernel_size;

Measurements = zeros(num_actual_vector_states, num_actual_vector_states) + 1234;
%Measurements_code = zeros(2, num_RTPS_phase_states^2*num_MODES);
Mapping = zeros(num_target_gain_states, num_target_phase_states);

Selected_Measurements = zeros(num_target_gain_states, num_target_phase_states);

target_gain_states_dB_normalized = linspace(-1*num_target_gain_states + 1, 0, num_target_gain_states);
target_gain_states_dB = zeros(1, num_target_gain_states);
target_gain_states = zeros(1, num_target_gain_states);

target_phase_states = linspace(0, 2*pi - target_phase_resolution, num_target_phase_states);

%actual_phase_states = linspace(0, 2*pi - actual_phase_resolution, num_actual_phase_states);

Current_Calibration_Gain_Index = Starting_Gain_Index;
Current_Calibration_Phase_Index = 1;

Current_Point_Iteration_Count = 0;

measurement_counter = 0;
total_measurement_counter = 0;



% plot(sweep_reading(1, :), "o");
% sweep_reading_ang = angle(sweep_reading)*180/pi;

%plot(simulation_data(1:95, 1), "o");

%plot(abs(channel1_S21_38r5GHz(:, 1)));

figure;
%set(gcf, 'Position',  [900, 300, 1000, 800]);
%movegui(gcf,'center');

disp(" ");
disp("Starting Calibration with kernel size of " + kernel_size);

next_state = "Start Calibration";
next_measurements = [];
next_choice = "";
current_measured_points = [];

while (next_state ~= "Finish Calibration")
    present_state = next_state;
    
    num_next_measurements = size(next_measurements, 1);

    if num_next_measurements ~= 0

        current_measured_points = zeros(num_next_measurements, 3);

        for i = 1:1:num_next_measurements
            current_measured_points(i, 1) = measurementClass.measure(next_measurements(i, :), next_choice);
            current_measured_points(i, 2:end) = next_measurements(i, :);

            if present_state == "Constellation Profile Characterization"
                plot(current_measured_points(i, 1) + 0.0001*1i, "O", "LineWidth", 1.5, "MarkerSize", 10, "Color", [0 0.4470 0.7410]);
                hold on
                drawnow
            end
        end

    end
    
    [next_measurements, next_choice, next_state] = Calibration_FSM(current_measured_points, present_state);
end

hold off

plot(Selected_Measurements(Starting_Gain_Index:Current_Calibration_Gain_Index, :), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "g");
hold on
plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
hold off
xlim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
ylim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
drawnow













%%
function [next_measurements, next_choice, next_state] = Calibration_FSM(current_measured_points, present_state)
global phase_offset num_target_phase_states Mapping Current_Calibration_Gain_Index Current_Calibration_Phase_Index target_gain_states ...
    target_phase_states phase_error_criteria phase_error_history Selected_Measurements Current_Point_Iteration_Count kernel_size original_kernel_size Starting_Gain_Index Ending_Gain_Index...
    num_actual_gain_states num_actual_phase_states gain_profile max_gain_measurement max_target_gain ...
    target_gain_states_dB_normalized target_gain_states_dB actual_gain_resolution kernel_offset measurement_counter num_actual_vector_states vector1_profile vector2_profile...
    theta1 theta2 reference_index reference_point vector1_envelop_profile vector2_envelop_profile max_gain min_gain VALIDATION num_hit total_num_hit num_target_gain_states

% next_phases is a N by 2 matrix where N is the number of phases to measured next and the 2 columns are phase 1 and phase 2.
% current_measured_points is a N by 1 vector where N is the number of points in the current measurements.
% Calibration_State is a string that indicates the current calibration state.

switch present_state
    case "Start Calibration"
        next_state = "Constellation Profile Characterization";

        vector1_profile(:, 1) = transpose(round(linspace(1, num_actual_vector_states, 20)));
        vector2_profile(:, 1) = transpose(round(linspace(1, num_actual_vector_states, 20)));

        reference_index = [vector1_profile(10, 1) vector2_profile(10, 1)];

        next_measurements(1, :) = reference_index;
        next_measurements(2:21, 1) = vector1_profile(:, 1);
        next_measurements(2:21, 2) = reference_index(2);
        next_measurements(22:41, 1) = reference_index(1);
        next_measurements(22:41, 2) = vector2_profile(:, 1);

        next_measurements(42:61, 1) = vector1_profile(:, 1);
        next_measurements(42:61, 2) = 1;
        next_measurements(62:81, 1) = vector1_profile(:, 1);
        next_measurements(62:81, 2) = num_actual_vector_states;

        next_measurements(82:101, 1) = 1;
        next_measurements(82:101, 2) = vector2_profile(:, 1);
        next_measurements(102:121, 1) = num_actual_vector_states;
        next_measurements(102:121, 2) = vector2_profile(:, 1);

        next_choice = "index";
        




    case "Constellation Profile Characterization"

        reference_point = current_measured_points(1, 1);

        vector1_profile(:, 2) = current_measured_points(2:21, 1);
        vector2_profile(:, 2) = current_measured_points(22:41, 1);

        inter1 = vector1_profile(end, 2) - vector1_profile(1, 2);
        inter2 = vector1_profile(round(20*5/8), 2) - vector1_profile(round(20*3/8), 2);
        normalized_vector1 = (inter1 + inter2)/abs(inter1 + inter2);

        inter1 = vector2_profile(end, 2) - vector2_profile(1, 2);
        inter2 = vector2_profile(round(20*5/8), 2) - vector2_profile(round(20*3/8), 2);
        normalized_vector2 = (inter1 + inter2)/abs(inter1 + inter2);

        theta1 = conversionClass.wrap22pi(angle(normalized_vector1));
        theta2 = conversionClass.wrap22pi(angle(normalized_vector2));

        first_point = vector1_profile(1, 2);
        for i = 1:1:20
            vector1_profile(i, 2) = abs(vector1_profile(i, 2) - first_point);
        end

        first_point = vector2_profile(1, 2);
        for i = 1:1:20
            vector2_profile(i, 2) = abs(vector2_profile(i, 2) - first_point);
        end

        %vector1_profile(:, 1) = vector1_profile(:, 1) - reference_index(1);
        % index = vector1_profile(:, 1) == 0;
        index = vector1_profile(:, 1) == reference_index(1);
        reference_vectorLength1 = vector1_profile(index, 2);
        vector1_profile(:, 2) = vector1_profile(:, 2) - reference_vectorLength1;

        %vector2_profile(:, 1) = vector2_profile(:, 1) - reference_index(2);
        % index = vector2_profile(:, 1) == 0;
        index = vector2_profile(:, 1) == reference_index(2);
        reference_vectorLength2 = vector2_profile(index, 2);
        vector2_profile(:, 2) = vector2_profile(:, 2) - reference_vectorLength2;
        
        for i = 1:1:20
        [vector2_envelop_profile(i, 1), vector2_envelop_profile(i, 2)] = conversionClass.cartesian2vectors(current_measured_points(41+i, 1) - reference_point);
        [vector2_envelop_profile(i, 3), vector2_envelop_profile(i, 4)] = conversionClass.cartesian2vectors(current_measured_points(61+i, 1) - reference_point);

        [vector1_envelop_profile(i, 1), vector1_envelop_profile(i, 2)] = conversionClass.cartesian2vectors(current_measured_points(81+i, 1) - reference_point);
        [vector1_envelop_profile(i, 3), vector1_envelop_profile(i, 4)] = conversionClass.cartesian2vectors(current_measured_points(101+i, 1) - reference_point);
        end

%         figure
%         plot(vector1_envelop_profile(:, 2), vector1_envelop_profile(:, 1))
%         figure
%         plot(vector1_envelop_profile(:, 4), vector1_envelop_profile(:, 3))
%         figure
%         plot(vector2_envelop_profile(:, 1), vector2_envelop_profile(:, 2))
%         figure
%         plot(vector2_envelop_profile(:, 3), vector2_envelop_profile(:, 4))

        max_gain_measurement = abs(current_measured_points(42:121, 1));
        max_target_gain = min(max_gain_measurement);
        max_gain = max(max_gain_measurement);
        min_gain = 0;
        
        %figure;
        %plot(gain_profile(:, 1), gain_profile(:, 2));
        %plot(max_gain_measurement);

        for i = 1:1:num_target_gain_states
            target_gain_states_dB(i) = target_gain_states_dB_normalized(i) + 20*log10(max_target_gain);
        end

        target_gain_states = 10.^(target_gain_states_dB/20);
        %min_target_gain = target_gain_states(1);

        actual_gain_resolution = (max_target_gain - min_gain)*2/num_actual_vector_states;
        
        max_target_gain = max_target_gain - 2*kernel_size*actual_gain_resolution;
        target_gain_states(end) = max_target_gain;
        target_gain_states_dB(end) = 20*log10(max_target_gain);

        for i = 1:1:num_target_gain_states
            plot_gain_circle(target_gain_states(num_target_gain_states + 1 - i));
            hold on
            drawnow
        end

        hold off

        disp(" ");
        disp("Characterization Finish");
        disp("Number of new measurements: " + measurement_counter);
    
        measurement_counter = 0;

        next_state = "Next Target Point";
        %Current_Calibration_Phase_Index = Current_Calibration_Phase_Index + 1;
        next_measurements = next_kernel();
        next_choice = "polar";

        plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)), 0, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
        hold on
        plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
        measurementClass.plot_measurements(next_measurements, "polar");

        % scatter(real(polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(1))), imag(polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(1))));
        % hold on

        


        




    case "Next Target Point"
        Current_Point_Iteration_Count = Current_Point_Iteration_Count + 1;

        plot(current_measured_points(:, 1), "X", "LineWidth", 1.5, "MarkerSize", 10, "Color", "r");
        hold on
        filtered_measurements = measurementClass.filter_measurements(current_measured_points);

        if Current_Calibration_Gain_Index > Starting_Gain_Index
            plot(Selected_Measurements(Starting_Gain_Index:Current_Calibration_Gain_Index - 1, :), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "g");
            hold on
        end
        plot(Selected_Measurements(Current_Calibration_Gain_Index, 1:Current_Calibration_Phase_Index - 1), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "g");
        xlim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
        ylim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
        drawnow
        hold on

        closest_measured_point = find_closest_measurement(current_measured_points);

        distance_error = abs(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)) - closest_measured_point(1, 1));
        
        %distance_error_criteria()

        if VALIDATION
            if distance_error < distance_error_criteria()
                valid = 1;
            else
                valid = measurementClass.measurement_validation(filtered_measurements(:, 1));
            end
        else
            valid = 1;

            if distance_error < distance_error_criteria()
                num_hit = num_hit + 1;
                total_num_hit = total_num_hit + 1;
            end
        end

        % if Current_Point_Iteration_Count > 10
        %     valid = 1;
        % end

        if valid
            kernel_offset = 0;
            Current_Point_Iteration_Count = 0;
            kernel_size = original_kernel_size;
            % RTPS_phase_resolution = original_RTPS_phase_resolution;
            % RTPS_gain_resolution = original_RTPS_gain_resolution;

            plot(conversionClass.polar2cartesian(closest_measured_point(1, 2), closest_measured_point(1, 3)), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "r");
            hold on
            plot(closest_measured_point(1, 1), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "g");
            xlim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
            ylim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
            drawnow
            hold off
            
            Selected_Measurements(Current_Calibration_Gain_Index, Current_Calibration_Phase_Index) = closest_measured_point(1, 1);
            %Mapping(Current_Calibration_Gain_Index, Current_Calibration_Phase_Index) = conversionClass.polar2code(closest_measured_point(2), closest_measured_point(3), selected_MODE, closest_measured_point(end));
            
            if Current_Calibration_Phase_Index == num_target_phase_states
    
                circle_report();
    
                if Current_Calibration_Gain_Index == Ending_Gain_Index
                    next_state = "Finish Calibration";
                    next_measurements = [];
                    next_choice = "";
                else
                    Current_Calibration_Gain_Index = Current_Calibration_Gain_Index + 1;
                    Current_Calibration_Phase_Index = 1;
                    
                    next_state = "Next Target Point";
                    next_measurements(1, 1) = target_gain_states(Current_Calibration_Gain_Index);
                    next_measurements(1, 2) = target_phase_states(Current_Calibration_Phase_Index);
                    next_choice = "polar";
                end
            else
    
                next_state = "Next Target Point";
                Current_Calibration_Phase_Index = Current_Calibration_Phase_Index + 1;
                next_measurements = next_kernel();
                next_choice = "polar";
            end
            
            plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index))+0.000001*1i, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
            hold on
            plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
            measurementClass.plot_measurements(next_measurements, "polar");
        else
            hold off

            % next_state = "Phase Offset Calibration";
            % next_measurements(1, 1) = target_gain_states(Current_Calibration_Gain_Index);
            % next_measurements(1, 2) = target_phase_states(Current_Calibration_Phase_Index);
            % next_choice = "polar";

            next_state = "Next Target Point";

            if Current_Point_Iteration_Count > 8
                 kernel_size = kernel_size + 2;
                 % kernel_size = kernel_size*4 + 1;
                 % RTPS_phase_resolution = RTPS_phase_resolution/1.5;
                 % RTPS_gain_resolution = RTPS_gain_resolution/1.5;
                 Current_Point_Iteration_Count = 0;
            end

            next_measurements = next_supporting_kernel(filtered_measurements);
            next_choice = "polar";

            plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index))+0.000001*1i, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
            hold on
            plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
            measurementClass.plot_measurements(next_measurements, "polar");
        end




    otherwise
end


end


















%%
function phase_offset = phase_offset_calculation(ideal_phase, measured_point)

phase_offset = conversionClass.wrap22pi(angle(measured_point)) - ideal_phase;

if phase_offset > pi
    phase_offset = phase_offset - 2*pi;
elseif phase_offset < -1*pi
    phase_offset = phase_offset + 2*pi;
end

end









function next_polar = next_kernel()
global Current_Calibration_Gain_Index Current_Calibration_Phase_Index kernel_size actual_phase_resolution target_gain_states ...
    target_phase_states actual_gain_resolution min_gain max_gain

k = 0;
for gain = 1:1:kernel_size
    for angle = 1:1:kernel_size
        next_gain = target_gain_states(Current_Calibration_Gain_Index) + actual_gain_resolution * (gain - (kernel_size + 1)/2);
        next_angle = conversionClass.wrap22pi(target_phase_states(Current_Calibration_Phase_Index) + actual_phase_resolution * (angle - (kernel_size + 1)/2));
        
        if (next_gain >= min_gain) && (next_gain <= max_gain) && (next_angle >= 0) && (next_angle <= 2*pi)
            k = k + 1;
        end
    end
end

next_polar = zeros(k, 2);


k = 1;
for gain = 1:1:kernel_size
    for angle = 1:1:kernel_size
        next_gain = target_gain_states(Current_Calibration_Gain_Index) + actual_gain_resolution * (gain - (kernel_size + 1)/2);
        next_angle = conversionClass.wrap22pi(target_phase_states(Current_Calibration_Phase_Index) + actual_phase_resolution * (angle - (kernel_size + 1)/2));
        
        if (next_gain >= min_gain) && (next_gain <= max_gain) && (next_angle >= 0) && (next_angle <= 2*pi)
            next_polar(k, 1) = next_gain;
            next_polar(k, 2) = next_angle;
            k = k + 1;
        end
    end
end

end





function  closest_measured_point = find_closest_measurement(current_measured_points)
global Current_Calibration_Gain_Index Current_Calibration_Phase_Index target_gain_states target_phase_states
    target_point = conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index));
    distance = abs(current_measured_points(:, 1) - target_point);
    index = distance == min(distance);
    closest_measured_point = current_measured_points(index, :);
end





function plot_gain_circle(gain)
    x0=0;
    y0=0;
    syms x y
    fimplicit((x-x0).^2 + (y-y0).^2 -gain^2, "Color", "k")
    
    hold on
    axis equal
end





function next_polar = next_supporting_kernel(filtered_measurements)
global Current_Calibration_Gain_Index Current_Calibration_Phase_Index kernel_size actual_phase_resolution target_gain_states ...
    target_phase_states actual_gain_resolution kernel_offset min_gain max_gain

    error_vector_sum = 0;

    ideal_kernel = next_kernel();

    for k = 1:1:size(filtered_measurements, 1)
        error_vector_sum = error_vector_sum + filtered_measurements(k, 1) - conversionClass.polar2cartesian(ideal_kernel(k, 1), ideal_kernel(k, 2));
    end

    average_error_vector = error_vector_sum/size(filtered_measurements, 1);

    kernel_offset = kernel_offset + average_error_vector;

    new_target_point = conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)) - kernel_offset;

    [new_target_gain, new_target_phase] = conversionClass.cartesian2polar(new_target_point);

    k = 0;
    for gain = 1:1:kernel_size
        for angle = 1:1:kernel_size
            next_gain = new_target_gain + actual_gain_resolution * (gain - (kernel_size + 1)/2);
            next_angle = conversionClass.wrap22pi(new_target_phase + actual_phase_resolution * (angle - (kernel_size + 1)/2));

            if (next_gain >= min_gain) && (next_gain <= max_gain) && (next_angle >= 0) && (next_angle <= 2*pi)
                k = k + 1;
            end
        end
    end

    next_polar = zeros(k, 2);


    k = 1;
    for gain = 1:1:kernel_size
        for angle = 1:1:kernel_size
            next_gain = new_target_gain + actual_gain_resolution * (gain - (kernel_size + 1)/2);
            next_angle = conversionClass.wrap22pi(new_target_phase + actual_phase_resolution * (angle - (kernel_size + 1)/2));

            if (next_gain >= min_gain) && (next_gain <= max_gain) && (next_angle >= 0) && (next_angle <= 2*pi)
                next_polar(k, 1) = next_gain;
                next_polar(k, 2) = next_angle;
                k = k + 1;
            end
        end
    end

end






% function next_polar = next_supporting_kernel(filtered_measurements)
% global Current_Calibration_Gain_Index Current_Calibration_Phase_Index kernel_size actual_phase_resolution target_gain_states ...
%     target_phase_states actual_gain_resolution min_target_gain max_target_gain
% 
%     error_vector_sum = 0;
% 
%     for k = 1:1:size(filtered_measurements, 1)
%         error_vector_sum = error_vector_sum + filtered_measurements(k, 1) - conversionClass.polar2cartesian(filtered_measurements(k, 2), filtered_measurements(k, 3));
%     end
% 
%     average_error_vector = error_vector_sum/size(filtered_measurements, 1);
% 
%     new_target_point = conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)) - average_error_vector;
% 
%     [new_target_gain, new_target_phase] = conversionClass.cartesian2polar(new_target_point);
% 
%     k = 0;
%     for gain = 1:1:kernel_size
%         for angle = 1:1:kernel_size
%             next_gain = new_target_gain + actual_gain_resolution * (gain - (kernel_size + 1)/2);
%             next_angle = conversionClass.wrap22pi(new_target_phase + actual_phase_resolution * (angle - (kernel_size + 1)/2));
% 
%             if (next_gain >= min_target_gain/2) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
%                 k = k + 1;
%             end
%         end
%     end
% 
%     next_polar = zeros(k, 2);
% 
% 
%     k = 1;
%     for gain = 1:1:kernel_size
%         for angle = 1:1:kernel_size
%             next_gain = new_target_gain + actual_gain_resolution * (gain - (kernel_size + 1)/2);
%             next_angle = conversionClass.wrap22pi(new_target_phase + actual_phase_resolution * (angle - (kernel_size + 1)/2));
% 
%             if (next_gain >= min_target_gain/2) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
%                 next_polar(k, 1) = next_gain;
%                 next_polar(k, 2) = next_angle;
%                 k = k + 1;
%             end
%         end
%     end
% 
% end







function circle_report()
global Current_Calibration_Gain_Index target_gain_states target_gain_states_dB target_phase_states Selected_Measurements measurement_counter total_measurement_counter Ending_Gain_Index Starting_Gain_Index phase_error_sum gain_error_sum...
    VALIDATION num_hit total_num_hit num_target_phase_states

    actual_phase = angle(Selected_Measurements(Current_Calibration_Gain_Index, :));
    
    for i = round(size(actual_phase, 2)/3) : 1 : size(actual_phase, 2)
        actual_phase(1, i) = conversionClass.wrap22pi(actual_phase(1, i));
    end

    phase_RMS_error = rmse(target_phase_states, actual_phase);
    gain_RMS_error = rmse(target_gain_states(Current_Calibration_Gain_Index), abs(Selected_Measurements(Current_Calibration_Gain_Index, :)));

    phase_error_sum = phase_error_sum + phase_RMS_error^2;
    gain_error_sum = gain_error_sum + gain_RMS_error^2;

    disp(" ");
    disp("Gain Circle " + Current_Calibration_Gain_Index + " at " + target_gain_states(Current_Calibration_Gain_Index) + " / " + target_gain_states_dB(Current_Calibration_Gain_Index) + " dB");
    disp("RMS Phase Error: " + phase_RMS_error + " / " + phase_RMS_error*180/pi + " degrees");
    disp("RMS Gain Error: " + gain_RMS_error + " / " + 10*log10(gain_RMS_error) + " dB");

    if ~VALIDATION
        hit_rate = num_hit/num_target_phase_states*100;
        disp("Hit rate: " + hit_rate + "%");
        num_hit = 0;
    else
        disp("Number of new measurements: " + measurement_counter);
        measurement_counter = 0;
    end


    if Current_Calibration_Gain_Index == Ending_Gain_Index
    
        total_RMS_phase_error = sqrt(phase_error_sum/(Ending_Gain_Index - Starting_Gain_Index + 1));
        total_RMS_gain_error = sqrt(gain_error_sum/(Ending_Gain_Index - Starting_Gain_Index + 1));

        disp(" ");
        disp("Calibration finish");
        disp("Total RMS Phase Error: " + total_RMS_phase_error + " / " + total_RMS_phase_error*180/pi + " degrees");
        disp("Total RMS Gain Error: " + total_RMS_gain_error + " / " + 10*log10(total_RMS_gain_error) + " dB");
        
        if ~VALIDATION
            total_hit_rate = total_num_hit/(num_target_phase_states*(Ending_Gain_Index - Starting_Gain_Index + 1))*100;
            disp("Total hit rate: " + total_hit_rate + "%");
        else
            disp("Total number of measurements for " + (Ending_Gain_Index - Starting_Gain_Index + 1) + " gain circles: " + total_measurement_counter);
        end

    end

end










function criteria = distance_error_criteria()
global actual_phase_resolution actual_gain_resolution target_gain_states Current_Calibration_Gain_Index

phase_variation = abs(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), 1) - conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), 1 + actual_phase_resolution));
criteria = min(phase_variation, actual_gain_resolution)*2;
end