global num_target_gain_states num_target_phase_states Measurements Mapping_SI Current_Calibration_Gain_Index Current_Calibration_Phase_Index target_gain_states ...
     target_phase_states  phase_error_criteria kernel_size target_phase_resolution  ...
     lowest_detectable_gain_dB  target_gain_states_dB phase_error_history  Selected_Measurements Current_Point_Iteration_Count original_kernel_size filter_tolerance Starting_Gain_Index Ending_Gain_Index...
     measurement_counter num_actual_gain_states num_actual_phase_states gain_profile phase_profile gain2phaseVariation max_gain_measurement max_target_gain ...
     phase_offset target_gain_states_dB_normalized actual_phase_resolution actual_phase_states min_target_gain total_measurement_counter kernel_offset VALIDATION num_hit total_num_hit...
     phase_error_sum gain_error_sum LEARNING_SAMPLE_SIZE Adapted_MODEL ENABLE_OUTLINE_SAMPLING GAIN_PROFILE_SIZE USE_MACHINE_LEARNING SAMPLING_PATTERN EQUAL_SPACING_SAMPLING ENABLE_UNSUPERVISED_CALIBRATION_CHECK...
     OUTLINE_PROFILE_SIZE max_phase_error max_gain_error

warning ("off", "all");

tic;
measurementClass.measurementSetup();

%%
VALIDATION = 1;
ENABLE_UNSUPERVISED_CALIBRATION_CHECK = 1;  % if enabled, unsupervised calibration results will be checked by measurement
PLOT_TARGET_POINTS = 1;


%%
USE_MACHINE_LEARNING = 1;
SAMPLING_PATTERN = "woven";    %choose "uniform", "woven" or "random"
EQUAL_SPACING_SAMPLING = 1;
LEARNING_SAMPLE_SIZE = 500;
ENABLE_OUTLINE_SAMPLING = 0;

GAIN_PROFILE_SIZE = 10;
OUTLINE_PROFILE_SIZE = 30;


%%
kernel_size = 1;
lowest_detectable_gain_dB = -8;

Starting_Gain_Index = 1;
Ending_Gain_Index = 8;

filter_tolerance = 1;



%%
min_target_gain = 0;
max_target_gain = 0;
max_phase_error = 0;
max_gain_error = 0;

phase_error_sum = 0;
gain_error_sum = 0;

phase_offset = 0;
kernel_offset = 0;

num_target_gain_states = 12;
num_target_phase_states = 64;

num_actual_gain_states = 256;
num_actual_phase_states = 256;

target_phase_resolution = 2*pi/num_target_phase_states;
actual_phase_resolution = 2*pi/num_actual_phase_states;

phase_error_history = zeros(2, 2);

phase_error_criteria = actual_phase_resolution;


original_kernel_size = kernel_size;


gain_profile = zeros(GAIN_PROFILE_SIZE, 2);
phase_profile = zeros(OUTLINE_PROFILE_SIZE, 2);
gain2phaseVariation = zeros(GAIN_PROFILE_SIZE, 2);
max_gain_measurement = zeros(num_actual_phase_states, 1);
max_target_gain = 0;


Measurements = zeros(num_actual_phase_states, num_actual_phase_states) + 1234;
Mapping_SI = zeros(num_target_gain_states, num_target_phase_states);

Selected_Measurements = zeros(num_target_gain_states, num_target_phase_states);

target_gain_states_dB_normalized = linspace(-1*num_target_gain_states + 1, 0, num_target_gain_states);
target_gain_states_dB = zeros(1, num_target_gain_states);
target_gain_states = zeros(1, num_target_gain_states);

target_phase_states = linspace(0, 2*pi - target_phase_resolution, num_target_phase_states);

actual_phase_states = linspace(0, 2*pi - actual_phase_resolution, num_actual_phase_states);

Current_Calibration_Gain_Index = Starting_Gain_Index;
Current_Calibration_Phase_Index = 1;

Current_Point_Iteration_Count = 0;

measurement_counter = 0;
total_measurement_counter = 0;

num_hit = 0;
total_num_hit = 0;




figure;
set(gcf, 'Position',  [400, 150, 1000, 800]);
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

            if present_state == "Gain and Phase Profile Characterization" || present_state == "Training" 
                plot(current_measured_points(i, 1), "O", "LineWidth", 1.5, "MarkerSize", 10, "Color", [0 0.4470 0.7410]);
                hold on
                drawnow
            end
        end

    end
    
    [next_measurements, next_choice, next_state] = Calibration_FSM(current_measured_points, present_state);
end

hold off

save("Mapping_SI.mat", "Mapping_SI");

disp(" ");
disp("Saved mapping to Mapping_SI.mat");

if VALIDATION || ENABLE_UNSUPERVISED_CALIBRATION_CHECK
    if PLOT_TARGET_POINTS
        for i = Starting_Gain_Index:1:Ending_Gain_Index
            for j = 1:1:num_target_phase_states
                plot(conversionClass.polar2cartesian(target_gain_states(i), target_phase_states(j))+0.000001*1i, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
                hold on
            end
        end
    end
    
    plot(Selected_Measurements(Starting_Gain_Index:Current_Calibration_Gain_Index, :), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "g");
    hold on
    plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
    hold off
    xlim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
    ylim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
    drawnow
end


CalibrationTime = toc;

disp("Calibration Time: " + CalibrationTime + " seconds");

measurementClass.measurementOFF();










%%
function [next_measurements, next_choice, next_state] = Calibration_FSM(current_measured_points, present_state)
global num_target_phase_states num_target_gain_states Mapping_SI Current_Calibration_Gain_Index Current_Calibration_Phase_Index target_gain_states ...
    target_phase_states Selected_Measurements Current_Point_Iteration_Count kernel_size original_kernel_size Starting_Gain_Index Ending_Gain_Index...
    num_actual_gain_states num_actual_phase_states gain_profile phase_profile gain2phaseVariation max_gain_measurement max_target_gain ...
    target_gain_states_dB_normalized target_gain_states_dB min_target_gain actual_gain_resolution actual_phase_resolution kernel_offset measurement_counter max_gain min_gain VALIDATION num_hit total_num_hit...
    LEARNING_SAMPLE_SIZE training_dataset TOTAL_SAMPLE GAIN_PROFILE_SIZE Adapted_MODEL ENABLE_OUTLINE_SAMPLING NUM_OUTLINE_SAMPLE USE_MACHINE_LEARNING SAMPLING_PATTERN ADJUSTED_LEARNING_SAMPLE_SIZE...
    EQUAL_SPACING_SAMPLING ENABLE_UNSUPERVISED_CALIBRATION_CHECK OUTLINE_PROFILE_SIZE

% current_measured_points is a N by 1 vector where N is the number of points in the current measurements.
% Calibration_State is a string that indicates the current calibration state.

switch present_state
    case "Start Calibration"

        if USE_MACHINE_LEARNING
            next_state = "Training";

            disp(" ");
            disp("Using Machine Learning");
            disp("Using " + SAMPLING_PATTERN + " sampling pattern");


            if SAMPLING_PATTERN == "random"
                next_measurements(1 : OUTLINE_PROFILE_SIZE, 1) = num_actual_gain_states;
                next_measurements(1 : OUTLINE_PROFILE_SIZE, 2) = transpose(round(linspace(1, num_actual_phase_states, OUTLINE_PROFILE_SIZE)));
    
                NUM_OUTLINE_SAMPLE = OUTLINE_PROFILE_SIZE;
                ADJUSTED_LEARNING_SAMPLE_SIZE = LEARNING_SAMPLE_SIZE;
                TOTAL_SAMPLE = NUM_OUTLINE_SAMPLE + ADJUSTED_LEARNING_SAMPLE_SIZE;

                next_measurements(NUM_OUTLINE_SAMPLE + 1 : TOTAL_SAMPLE, 1) = conversionClass.parameter_denormalization(rand(LEARNING_SAMPLE_SIZE, 1), 1, num_actual_gain_states);
                next_measurements(NUM_OUTLINE_SAMPLE + 1 : TOTAL_SAMPLE, 2) = conversionClass.parameter_denormalization(rand(LEARNING_SAMPLE_SIZE, 1), 1, num_actual_phase_states);
            else
                if EQUAL_SPACING_SAMPLING
                    num_sampling_gain = round(sqrt(LEARNING_SAMPLE_SIZE)*num_actual_gain_states/num_actual_phase_states);
                    possible_divisors = divisors(num_actual_gain_states);
                    distance = abs(possible_divisors - num_sampling_gain);
                    index = distance == min(distance);
                    matches = possible_divisors(index);
                    adjusted_num_sampling_gain = matches(1);
                    gain_index_interval = round(num_actual_gain_states/adjusted_num_sampling_gain);

                    num_sampling_phase = round(LEARNING_SAMPLE_SIZE/adjusted_num_sampling_gain);
                    possible_divisors = divisors(num_actual_phase_states);
                    distance = abs(possible_divisors - num_sampling_phase);
                    index = distance == min(distance);
                    matches = possible_divisors(index);
                    adjusted_num_sampling_phase = matches(1);
                    phase_index_interval = round(num_actual_phase_states/adjusted_num_sampling_phase);

                    NUM_OUTLINE_SAMPLE = 0;
                    ADJUSTED_LEARNING_SAMPLE_SIZE = adjusted_num_sampling_gain*adjusted_num_sampling_phase;
                    TOTAL_SAMPLE = NUM_OUTLINE_SAMPLE + ADJUSTED_LEARNING_SAMPLE_SIZE;

                    if SAMPLING_PATTERN == "uniform"
                        for i = 1:1:adjusted_num_sampling_gain
                            for j = 1:1:adjusted_num_sampling_phase
                                next_measurements((i-1)*adjusted_num_sampling_phase + j, 1) = i*gain_index_interval;
                                next_measurements((i-1)*adjusted_num_sampling_phase + j, 2) = 1 + (j-1) * phase_index_interval;
                            end
                        end

                    else
                        rotation_index_step = round(phase_index_interval/2) + 1;

                        for i = 1:1:adjusted_num_sampling_gain
                            for j = 1:1:adjusted_num_sampling_phase
                                next_measurements((i-1)*adjusted_num_sampling_phase + j, 1) = i*gain_index_interval;
                                next_measurements((i-1)*adjusted_num_sampling_phase + j, 2) = mod(1 + (j-1) * phase_index_interval + (i-1)*rotation_index_step, num_actual_phase_states + 1);
                            end
                        end
                    end
                else % if not equal spacing
                    num_sampling_gain = round(sqrt(LEARNING_SAMPLE_SIZE)*num_actual_gain_states/num_actual_phase_states);
                    sample_gain_index = transpose(round(linspace(1, num_actual_gain_states, num_sampling_gain)));

                    num_sampling_phase = round(LEARNING_SAMPLE_SIZE/num_sampling_gain);
                    phase_index_interval = round((num_actual_phase_states - 1)/(num_sampling_phase - 1));
                    sample_phase_index = transpose(round(linspace(1, num_actual_phase_states - phase_index_interval, num_sampling_phase)));

                    NUM_OUTLINE_SAMPLE = 0;
                    ADJUSTED_LEARNING_SAMPLE_SIZE = num_sampling_gain*num_sampling_phase;
                    TOTAL_SAMPLE = NUM_OUTLINE_SAMPLE + ADJUSTED_LEARNING_SAMPLE_SIZE;

                    if SAMPLING_PATTERN == "uniform"
                        for i = 1:1:num_sampling_gain
                            next_measurements(1 + (i-1)*num_sampling_phase: i*num_sampling_phase, 1) = sample_gain_index(i);
                            next_measurements(1 + (i-1)*num_sampling_phase: i*num_sampling_phase, 2) = sample_phase_index;
                        end
    
                    else % woven
                        translation_index_step = round(abs(sample_phase_index(1)-sample_phase_index(2))/2);

                        for i = 1:1:num_sampling_gain
                            next_measurements(1 + (i-1)*num_sampling_phase: i*num_sampling_phase, 1) = sample_gain_index(i);

                            translated_phase_index = mod(sample_phase_index + (i-1)*translation_index_step, num_actual_phase_states + 1);
                            next_measurements(1 + (i-1)*num_sampling_phase: i*num_sampling_phase, 2) = translated_phase_index;
                        end
                    end

                end
            end
            disp("Learning sample size after adjustment: " + ADJUSTED_LEARNING_SAMPLE_SIZE);

            if EQUAL_SPACING_SAMPLING
                disp("Disable EQUAL_SPACING_SAMPLING for closer learning sample size to the set value.")
            end
            
            next_choice = "index";
        else
            next_state = "Gain and Phase Profile Characterization";

            disp(" ");
            disp("Using Point Translation Algorithm");

            gain_profile(:, 1) = transpose(round(linspace(1, num_actual_gain_states, GAIN_PROFILE_SIZE)));
            next_measurements(1:GAIN_PROFILE_SIZE, 1) = gain_profile(:, 1);
            next_measurements(1:GAIN_PROFILE_SIZE, 2) = 1;
            next_measurements(GAIN_PROFILE_SIZE + 1:GAIN_PROFILE_SIZE + OUTLINE_PROFILE_SIZE, 1) = num_actual_gain_states;
            next_measurements(GAIN_PROFILE_SIZE + 1:GAIN_PROFILE_SIZE + OUTLINE_PROFILE_SIZE, 2) = transpose(round(linspace(1, num_actual_phase_states, OUTLINE_PROFILE_SIZE)));
            next_choice = "index";
        end
            







        case "Gain and Phase Profile Characterization"
            gain_profile(:, 2) = abs(current_measured_points(1:GAIN_PROFILE_SIZE, 1));
    
            phase_profile(:, 1) = transpose(round(linspace(1, num_actual_phase_states, OUTLINE_PROFILE_SIZE)));
            phase_profile(:, 2) = unwrap(angle(current_measured_points(GAIN_PROFILE_SIZE + 1:GAIN_PROFILE_SIZE + OUTLINE_PROFILE_SIZE, 1)));
    
            gain2phaseVariation(:, 1) = gain_profile(:, 1);
            gain2phaseVariation(:, 2) = angle(current_measured_points(1:GAIN_PROFILE_SIZE, 1)) - angle(current_measured_points(GAIN_PROFILE_SIZE, 1));
    
    
            max_gain_measurement = abs(current_measured_points(GAIN_PROFILE_SIZE + 1:GAIN_PROFILE_SIZE + OUTLINE_PROFILE_SIZE, 1));
            max_target_gain = min(max_gain_measurement);
            max_gain = max(max_gain_measurement);
            min_gain = abs(current_measured_points(1, 1));
            
    
            for i = 1:1:num_target_gain_states
                target_gain_states_dB(i) = target_gain_states_dB_normalized(i) + 20*log10(max_target_gain);
            end
    
            target_gain_states = 10.^(target_gain_states_dB/20);
            min_target_gain = target_gain_states(1);
    
            actual_gain_resolution = (max_target_gain - min_gain)/num_actual_gain_states;
            
            max_target_gain = max_target_gain - 5*kernel_size*actual_gain_resolution;
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


            if VALIDATION || ENABLE_UNSUPERVISED_CALIBRATION_CHECK
                next_state = "Next Target Point";
                next_measurements = next_kernel();
                next_choice = "polar";

                plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)), 0, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
                hold on
                plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
                measurementClass.plot_measurements(next_measurements, "polar");
            else
                next_state = "Unsupervised Mapping Generation";
                next_measurements = [];
                next_choice = "";
            end
    
            









    case "Training"

        max_gain_measurement_index = current_measured_points(:, 2) == num_actual_gain_states;
        max_gain_measurement = abs(current_measured_points(max_gain_measurement_index, 1));
        max_target_gain = min(max_gain_measurement);
        max_gain = max(max_gain_measurement);
        min_gain = 0;

        if SAMPLING_PATTERN == "random" && ENABLE_OUTLINE_SAMPLING
            training_dataset = zeros(4, TOTAL_SAMPLE);

            training_dataset(1, 1:TOTAL_SAMPLE) = real(current_measured_points(1:TOTAL_SAMPLE, 1))./max_gain;
            training_dataset(2, 1:TOTAL_SAMPLE) = imag(current_measured_points(1:TOTAL_SAMPLE, 1))./max_gain;

            for i = 1:1:TOTAL_SAMPLE
                sample_gain_index = current_measured_points(i, 2);
                normalized_sample_gain_index = conversionClass.parameter_normalization(sample_gain_index, 1, num_actual_gain_states);

                sample_phase_index = current_measured_points(i, 3);
                twopi_normalized_sample_phase_index = conversionClass.parameter_normalization(sample_phase_index, 1, num_actual_phase_states)*(2*pi - actual_phase_resolution);

                [training_dataset(3, i), training_dataset(4, i)] = conversionClass.polar2rec(normalized_sample_gain_index, twopi_normalized_sample_phase_index);

            end

        else
            training_dataset = zeros(4, ADJUSTED_LEARNING_SAMPLE_SIZE);

            training_dataset(1, 1:ADJUSTED_LEARNING_SAMPLE_SIZE) = real(current_measured_points(NUM_OUTLINE_SAMPLE + 1 : TOTAL_SAMPLE, 1))./max_gain;
            training_dataset(2, 1:ADJUSTED_LEARNING_SAMPLE_SIZE) = imag(current_measured_points(NUM_OUTLINE_SAMPLE + 1 : TOTAL_SAMPLE, 1))./max_gain;

            for i = 1:1:ADJUSTED_LEARNING_SAMPLE_SIZE
                sample_gain_index = current_measured_points(NUM_OUTLINE_SAMPLE + i, 2);
                normalized_sample_gain_index = conversionClass.parameter_normalization(sample_gain_index, 1, num_actual_gain_states);

                sample_phase_index = current_measured_points(NUM_OUTLINE_SAMPLE + i, 3);
                twopi_normalized_sample_phase_index = conversionClass.parameter_normalization(sample_phase_index, 1, num_actual_phase_states)*(2*pi - actual_phase_resolution);

                [training_dataset(3, i), training_dataset(4, i)] = conversionClass.polar2rec(normalized_sample_gain_index, twopi_normalized_sample_phase_index);

            end
        end

        shuffled_training_dataset = training_dataset(:, randperm(size(training_dataset, 2)));

        shuffled_training_dataset_input = shuffled_training_dataset(1:2, :);
        shuffled_training_dataset_output = shuffled_training_dataset(3:4, :);


        hiddenLayerSize = 15;

        Adapted_MODEL = fitnet(hiddenLayerSize);
        Adapted_MODEL.divideParam.trainRatio = 0.7;
        Adapted_MODEL.divideParam.valRatio = 0.15;
        Adapted_MODEL.divideParam.testRatio = 0.15;
        
        Adapted_MODEL.trainParam.epochs = 5000;
        
        [Adapted_MODEL, tr] = train(Adapted_MODEL, shuffled_training_dataset_input, shuffled_training_dataset_output);
        
        save("Adapted_MODEL.mat", "Adapted_MODEL");



        %plot(gain_profile(:, 2), gain_profile(:, 1));
        %plot(max_gain_measurement);

        for i = 1:1:num_target_gain_states
            target_gain_states_dB(i) = target_gain_states_dB_normalized(i) + 20*log10(max_target_gain);
        end

        target_gain_states = 10.^(target_gain_states_dB/20);
        min_target_gain = target_gain_states(1);

        actual_gain_resolution = (max_target_gain - min_gain)/num_actual_gain_states;
        
        max_target_gain = max_target_gain - 5*kernel_size*actual_gain_resolution;
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

        if VALIDATION || ENABLE_UNSUPERVISED_CALIBRATION_CHECK
            next_state = "Next Target Point";
            next_measurements = next_kernel();
            next_choice = "model";

            plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)), 0, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
            hold on
            plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
            measurementClass.plot_measurements(next_measurements, "polar");
        else
            next_state = "Unsupervised Mapping Generation";
            next_measurements = [];
            next_choice = "";
        end
        
        
        
        







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


        if valid
            kernel_offset = 0;
            Current_Point_Iteration_Count = 0;
            kernel_size = original_kernel_size;

            plot(conversionClass.polar2cartesian(closest_measured_point(1, 2), closest_measured_point(1, 3)), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "r");
            hold on
            plot(closest_measured_point(1, 1), "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", "g");
            xlim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
            ylim([-1*(target_gain_states(Current_Calibration_Gain_Index)+0.1) target_gain_states(Current_Calibration_Gain_Index)+0.1]);
            drawnow
            hold off
            
            Selected_Measurements(Current_Calibration_Gain_Index, Current_Calibration_Phase_Index) = closest_measured_point(1, 1);

            if USE_MACHINE_LEARNING
                [selected_gain_index, selected_phase_index] = conversionClass.model2index_SI(closest_measured_point(1, 2), closest_measured_point(1, 3));
            else
                [selected_gain_index, selected_phase_index] = conversionClass.polar2index_SI(closest_measured_point(1, 2), closest_measured_point(1, 3));
            end

            Mapping_SI(Current_Calibration_Gain_Index, Current_Calibration_Phase_Index) = conversionClass.index2code(selected_gain_index, selected_phase_index);
            

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
                    next_measurements = next_kernel();
                    if USE_MACHINE_LEARNING
                        next_choice = "model";
                    else
                        next_choice = "polar";
                    end
                end
            else
    
                next_state = "Next Target Point";
                Current_Calibration_Phase_Index = Current_Calibration_Phase_Index + 1;
                next_measurements = next_kernel();
                if USE_MACHINE_LEARNING
                    next_choice = "model";
                else
                    next_choice = "polar";
                end
            end
            
            plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index))+0.000001*1i, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
            hold on
            plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
            measurementClass.plot_measurements(next_measurements, "polar");
        else
            hold off

            next_state = "Next Target Point";

            if Current_Point_Iteration_Count > 10
                 kernel_size = kernel_size + 2;
                 Current_Point_Iteration_Count = 0;
            end

            next_measurements = next_supporting_kernel(filtered_measurements);
            if USE_MACHINE_LEARNING
                next_choice = "model";
            else
                next_choice = "polar";
            end

            plot(conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index))+0.000001*1i, "O", "LineWidth", 1.5, "MarkerSize", 10, "MarkerFaceColor", [0 0.4470 0.7410]);
            hold on
            plot_gain_circle(target_gain_states(Current_Calibration_Gain_Index));
            measurementClass.plot_measurements(next_measurements, "polar");
        end










    case "Unsupervised Mapping Generation"

        for target_gain_index = Starting_Gain_Index:1:Ending_Gain_Index
            for target_phase_index = 1:1:num_target_phase_states
                if USE_MACHINE_LEARNING
                    [gain_index, phase_index] = conversionClass.model2index_SI(target_gain_states(target_gain_index), target_phase_states(target_phase_index));
                else
                    [gain_index, phase_index] = conversionClass.polar2index_SI(target_gain_states(target_gain_index), target_phase_states(target_phase_index));
                end

                Mapping_SI(target_gain_index, target_phase_index) = conversionClass.index2code(gain_index, phase_index);
            end
        end

        next_state = "Finish Calibration";
        next_measurements = [];
        next_choice = "";




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
    target_phase_states actual_gain_resolution min_target_gain max_target_gain min_gain

k = 0;
for gain = 1:1:kernel_size
    for angle = 1:1:kernel_size
        next_gain = target_gain_states(Current_Calibration_Gain_Index) + actual_gain_resolution * (gain - (kernel_size + 1)/2);
        next_angle = conversionClass.wrap22pi(target_phase_states(Current_Calibration_Phase_Index) + actual_phase_resolution * (angle - (kernel_size + 1)/2));
        
        if (next_gain >= min_gain) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
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
        
        if (next_gain >= min_gain) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
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



% 
% 
% function next_polar = next_supporting_kernel(filtered_measurements)
% global Current_Calibration_Gain_Index Current_Calibration_Phase_Index kernel_size actual_phase_resolution target_gain_states ...
%     target_phase_states actual_gain_resolution min_target_gain max_target_gain kernel_offset min_gain
% 
%     error_vector_sum = 0;
% 
%     ideal_kernel = next_kernel();
% 
%     for k = 1:1:size(filtered_measurements, 1)
%         error_vector_sum = error_vector_sum + filtered_measurements(k, 1) - conversionClass.polar2cartesian(ideal_kernel(k, 1), ideal_kernel(k, 2));
%     end
% 
%     average_error_vector = error_vector_sum/size(filtered_measurements, 1);
% 
%     kernel_offset = kernel_offset + average_error_vector;
% 
%     new_target_point = conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)) - kernel_offset;
% 
%     [new_target_gain, new_target_phase] = conversionClass.cartesian2polar(new_target_point);
% 
%     k = 0;
%     for gain = 1:1:kernel_size
%         for angle = 1:1:kernel_size
%             next_gain = new_target_gain + actual_gain_resolution * (gain - (kernel_size + 1)/2);
%             next_angle = conversionClass.wrap22pi(new_target_phase + actual_phase_resolution * (angle - (kernel_size + 1)/2));
% 
%             if (next_gain >= min_gain) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
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
%             if (next_gain >= min_gain) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
%                 next_polar(k, 1) = next_gain;
%                 next_polar(k, 2) = next_angle;
%                 k = k + 1;
%             end
%         end
%     end
% 
% end






function next_polar = next_supporting_kernel(filtered_measurements)
global Current_Calibration_Gain_Index Current_Calibration_Phase_Index kernel_size actual_phase_resolution target_gain_states ...
    target_phase_states actual_gain_resolution min_target_gain max_target_gain min_gain

    error_vector_sum = 0;

    for k = 1:1:size(filtered_measurements, 1)
        error_vector_sum = error_vector_sum + filtered_measurements(k, 1) - conversionClass.polar2cartesian(filtered_measurements(k, 2), filtered_measurements(k, 3));
    end

    average_error_vector = error_vector_sum/size(filtered_measurements, 1);

    new_target_point = conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index)) - average_error_vector;

    [new_target_gain, new_target_phase] = conversionClass.cartesian2polar(new_target_point);

    k = 0;
    for gain = 1:1:kernel_size
        for angle = 1:1:kernel_size
            next_gain = new_target_gain + actual_gain_resolution * (gain - (kernel_size + 1)/2);
            next_angle = conversionClass.wrap22pi(new_target_phase + actual_phase_resolution * (angle - (kernel_size + 1)/2));

            if (next_gain >= min_gain) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
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

            if (next_gain >= min_gain) && (next_gain <= max_target_gain + 2*kernel_size*actual_gain_resolution) && (next_angle >= 0) && (next_angle <= 2*pi)
                next_polar(k, 1) = next_gain;
                next_polar(k, 2) = next_angle;
                k = k + 1;
            end
        end
    end

end







function circle_report()
    global Current_Calibration_Gain_Index target_gain_states target_gain_states_dB target_phase_states Selected_Measurements measurement_counter total_measurement_counter Ending_Gain_Index Starting_Gain_Index phase_error_sum gain_error_sum...
        VALIDATION num_hit total_num_hit num_target_phase_states total_RMS_phase_error_degree total_RMS_gain_error_dB max_phase_error max_gain_error
    
        actual_phase = angle(Selected_Measurements(Current_Calibration_Gain_Index, :));
        
        for i = round(size(actual_phase, 2)/3) : 1 : size(actual_phase, 2)
            actual_phase(1, i) = conversionClass.wrap22pi(actual_phase(1, i));
        end
    
        phase_RMS_error = rmse(target_phase_states, actual_phase);
        gain_RMS_error = rmse(target_gain_states(Current_Calibration_Gain_Index), abs(Selected_Measurements(Current_Calibration_Gain_Index, :)));
    
        phase_error_sum = phase_error_sum + phase_RMS_error^2;
        gain_error_sum = gain_error_sum + gain_RMS_error^2;
    

        if  max(abs(target_phase_states - actual_phase)) > max_phase_error
            max_phase_error = max(abs(target_phase_states - actual_phase));
        end

        if max(abs(abs(Selected_Measurements(Current_Calibration_Gain_Index, :)) - target_gain_states(Current_Calibration_Gain_Index))) > max_gain_error
            max_gain_error = max(abs(abs(Selected_Measurements(Current_Calibration_Gain_Index, :)) - target_gain_states(Current_Calibration_Gain_Index)));
        end

        disp(" ");
        disp("Gain Circle " + Current_Calibration_Gain_Index + " at " + target_gain_states(Current_Calibration_Gain_Index) + " / " + target_gain_states_dB(Current_Calibration_Gain_Index) + " dB");
        disp("RMS Phase Error: " + phase_RMS_error + " / " + phase_RMS_error*180/pi + " degrees");
        disp("RMS Gain Error: " + gain_RMS_error + " / " + 20*log10(gain_RMS_error) + " dB");
    
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

            total_RMS_phase_error_degree = total_RMS_phase_error*180/pi;
            total_RMS_gain_error_dB = 20*log10(total_RMS_gain_error);

            max_phase_error_degree = max_phase_error*180/pi;
            max_gain_error_dB = 10*log10(max_gain_error);
    
            disp(" ");
            disp("Calibration finish");
            disp("Total RMS Phase Error: " + total_RMS_phase_error + " / " + total_RMS_phase_error_degree + " degrees");
            disp("Peak Phase Error: " + max_phase_error + " / " + max_phase_error_degree + " degrees");
            disp("Total RMS Gain Error: " + total_RMS_gain_error + " / " + total_RMS_gain_error_dB + " dB");
            disp("Peak Gain Error: " + max_gain_error + " / " + max_gain_error_dB + " dB");
            
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
criteria = min(phase_variation, actual_gain_resolution)*3;
end