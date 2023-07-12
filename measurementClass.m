classdef measurementClass
    methods (Static)
        
        function reading = measure(next, choice, MODE, SOLUTION)
        global DC_offset phase1_offset phase2_offset magnitude_scaling_factor Measurements measurement_counter total_measurement_counter
        
            if size(next, 1) == 0
                reading = [];
        
            elseif choice == "phases"
                vector1_phase = conversionClass.wrap22pi(next(1));
                vector2_phase = conversionClass.wrap22pi(next(2));
        
            elseif choice == "polar"
                uncompensated_target_point = conversionClass.polar2cartesian(next(1), next(2));
                target_point = measurementClass.DC_offset_compensation(uncompensated_target_point, DC_offset, magnitude_scaling_factor);
                [uncompensated_vector1_phase, uncompensated_vector2_phase] = conversionClass.cartesian2phases(target_point);
                if SOLUTION == 2
                    [uncompensated_vector1_phase, uncompensated_vector2_phase] = conversionClass.swap(uncompensated_vector1_phase, uncompensated_vector2_phase);
                end
                [vector1_phase, vector2_phase] = measurementClass.phase_offset_compensation(uncompensated_vector1_phase, uncompensated_vector2_phase, phase1_offset, phase2_offset);
        
                %show_codeword(codeword);
            elseif choice == "cartesian"
                target_point = measurementClass.DC_offset_compensation(next, DC_offset, magnitude_scaling_factor);
                [uncompensated_vector1_phase, uncompensated_vector2_phase] = conversionClass.cartesian2phases(target_point);
                if SOLUTION == 2
                    [uncompensated_vector1_phase, uncompensated_vector2_phase] = conversionClass.swap(uncompensated_vector1_phase, uncompensated_vector2_phase);
                end
                [vector1_phase, vector2_phase] = measurementClass.phase_offset_compensation(uncompensated_vector1_phase, uncompensated_vector2_phase, phase1_offset, phase2_offset);
                
            else
                disp("Error: Invalid choise of measurement");
            end
        
            vector1_phase_index = conversionClass.phase2RTPS_phase_index(vector1_phase) + 1;
            vector2_phase_index = conversionClass.phase2RTPS_phase_index(vector2_phase) + 1;
        
            previous_measurement = Measurements(vector1_phase_index, vector2_phase_index, MODE);
            
            if previous_measurement == 1234
                codeword = conversionClass.vectors2code(vector1_phase, vector2_phase, MODE);
                reading = measurementClass.SIMULATION_READ(codeword);
                Measurements(vector1_phase_index, vector2_phase_index, MODE) = reading;
                measurement_counter = measurement_counter + 1;
                total_measurement_counter = total_measurement_counter + 1;
            else
                reading = previous_measurement;
            end
        end
        
        
        
        function compensated_point = DC_offset_compensation(point, DC_offset, magnitude_scaling_factor)
            compensated_point = point - DC_offset * magnitude_scaling_factor;
        end
        
        
        
        
        
        function [compensated_vector1, compensated_vector2] = phase_offset_compensation(vector1, vector2, phase1_offset, phase2_offset)
            compensated_vector1 = conversionClass.wrap22pi(vector1 - phase1_offset);
            compensated_vector2 = conversionClass.wrap22pi(vector2 - phase2_offset);
        end
        
        
        
        
        
        function reading = OUTPHASER_READ(codeword)
            global S_dd21
        
            codeword_inSequence_bin = flip(dec2bin(codeword, 28));
            codeword1 = codeword_inSequence_bin(1:14);
            codeword2 = codeword_inSequence_bin(15:28);
        
            vector1_address = bin2dec(flip(codeword1(1:12))) + 1;
            if codeword1(13:14) == "10"
                vector1_address = vector1_address + 4096;
            end
        
            vector2_address = bin2dec(flip(codeword2(1:12))) + 1;
            if codeword2(13:14) == "10"
                vector2_address = vector2_address + 4096;
            end
        
            vector1_reading = S_dd21(vector1_address, 161);
            vector2_reading = S_dd21(vector2_address, 161);
        
            if abs(vector1_reading)<0.3
                vector1_reading = vector1_reading/abs(vector1_reading)*0.35;
            end
            if abs(vector2_reading)<0.3
                vector2_reading = vector2_reading/abs(vector2_reading)*0.35;
            end
        
            reading = 0.5*(vector1_reading + vector2_reading);
        
            reading = reading * 2;
        end
        

        
        
        
        function reading = RTPS_READ(codeword)
            global S_dd21
        
            codeword_inSequence_bin = flip(dec2bin(codeword, 14));
        
            vector1_address = bin2dec(flip(codeword_inSequence_bin(1:12))) + 1;
        
            if codeword_inSequence_bin(13:14) == "10"
                vector1_address = vector1_address + 4096;
            end
        
            reading = S_dd21(vector1_address, 161);
            
            if abs(reading)<0.3
                reading = reading/abs(reading)*0.35;
            end
        end
        
        
        
        
        
        function reading = RTPS_READ_FAKE(codeword)
        global RTPS_phase_resolution
        
            codeword_inSequence_bin = flip(dec2bin(codeword, 14));
        
            c0 = bin2dec(codeword_inSequence_bin(1:4));
            c1 = bin2dec(codeword_inSequence_bin(5:8));
            c2 = bin2dec(codeword_inSequence_bin(9:12));
        
            phase = (c0 + c1 + c2)*RTPS_phase_resolution;
        
            if codeword_inSequence_bin(13:14) == "10"
                phase = phase + pi;
            end
        
            reading = 0.5*cos(phase) + 1i*0.5*sin(phase);
        end
        
        
        
        
        
        function reading = SIMULATION_READ(codeword)
            global simulation_data magnitude_scaling_factor
        
            codeword_inSequence_bin = flip(dec2bin(codeword, 28));
            codeword1 = codeword_inSequence_bin(1:14);
            codeword2 = codeword_inSequence_bin(15:28);
        
            c0 = bin2dec(codeword1(1:4));
            c1 = bin2dec(codeword1(5:8));
            c2 = bin2dec(codeword1(9:12));
            c3 = bin2dec(codeword1(13:14));
        
            c4 = bin2dec(codeword2(1:4));
            c5 = bin2dec(codeword2(5:8));
            c6 = bin2dec(codeword2(9:12));
            c7 = bin2dec(codeword2(13:14));
        
            if (c1 == 0) && (c2 == 0)
                index1 = c0;
            elseif (c1 == 15) && (c2 == 0)
                index1 = c0 + 16;
            elseif (c1 == 15) && (c2 == 15)
                index1 = c0 + 32;
            end
        
            if c3 == 2
                index1 = index1 + 48;
            end
        
            if (c5 == 0) && (c6 == 0)
                index2 = c4;
            elseif (c5 == 15) && (c6 == 0)
                index2 = c4 + 16;
            elseif (c5 == 15) && (c6 == 15)
                index2 = c4 + 32;
            end
        
            if c7 == 2
                index2 = index2 + 48;
            end
        
            index = index1 + 1 + (index2 * 95);
        
            reading = simulation_data(index, 1) * magnitude_scaling_factor;
        end
        
        
        
        
        function show_codeword(codeword)
            codeword_inSequence_bin = flip(dec2bin(codeword, 28));
            codeword1 = codeword_inSequence_bin(1:14);
            codeword2 = codeword_inSequence_bin(15:28);
        
            c0 = bin2dec(codeword1(1:4));
            c1 = bin2dec(codeword1(5:8));
            c2 = bin2dec(codeword1(9:12));
            c3 = bin2dec(codeword1(13:14));
        
            c4 = bin2dec(codeword2(1:4));
            c5 = bin2dec(codeword2(5:8));
            c6 = bin2dec(codeword2(9:12));
            c7 = bin2dec(codeword2(13:14));
        
            disp([c0 c1 c2 c3 c4 c5 c6 c7]);
        end
        
        
        
       
        
        function plot_measurements(next, choice)
        global DC_offset phase1_offset phase2_offset magnitude_scaling_factor Measurements
        
        num_next = size(next, 1);
        points = zeros(num_next, 1);
        
            if num_next == 0
        
            elseif choice == "phases"
                for k = 1:1:num_next
                    points(k, 1) = conversionClass.phase2cartesian(next(k, 1), next(k, 2));
                end
        
            elseif choice == "polar"
                for k = 1:1:num_next
                    points(k, 1) = conversionClass.polar2cartesian(next(k, 1), next(k, 2));
                end
        
                %show_codeword(codeword);
            elseif choice == "cartesian"
                
            else
                disp("Error: Invalid choise of measurement");
            end
        
            plot(points, "O", "LineWidth", 1.5, "MarkerSize", 10, "Color", [0 0.4470 0.7410]);
            
            hold on
        
        end
        
        
        
        
        
        function double_filtered_points = filter_measurements(current_measured_points)
        global filter_tolerance
        
            distance = zeros(size(current_measured_points, 1), 1);
            for k = 1:1:size(current_measured_points, 1)
                distance(k, 1) = abs(current_measured_points(k, 1) - conversionClass.polar2cartesian(current_measured_points(k, 2), current_measured_points(k, 3)));
            end
        
            % points = current_measured_points(:, 1);
            % center = mean(points);
            % distance = abs(points - center);
        
            mean_distance = mean(distance, "all");
        
            outlier_indexes = find(distance > filter_tolerance * mean_distance);
        
            filtered_points = zeros(size(current_measured_points, 1) - size(outlier_indexes, 1), 3);
        
            j = 1;
        
            for k = 1:1:size(current_measured_points, 1)
                if ~ismember(k, outlier_indexes)
                    filtered_points(j, :) = current_measured_points(k, :);
                    j = j + 1;
                end
            end
        
        
            mean_data = mean(filtered_points(:, 1), "all");
            center_distance = abs(filtered_points(:, 1) - mean_data);
            mean_distance = mean(center_distance, "all");
        
            double_outlier_indexes = find(center_distance > filter_tolerance * mean_distance);
        
            double_filtered_points = zeros(size(filtered_points, 1) - size(double_outlier_indexes, 1), 3);
        
            j = 1;
        
            for k = 1:1:size(filtered_points, 1)
                if ~ismember(k, double_outlier_indexes)
                    double_filtered_points(j, :) = filtered_points(k, :);
                    j = j + 1;
                end
            end
        
            % plot(current_measured_points(:, 1), "O");
            % hold on
            % plot(filtered_points(:, 1), "X");
            % hold on
        end
        
        
        
        
        function valid = measurement_validation(measurement_points)
        global Current_Calibration_Gain_Index Current_Calibration_Phase_Index target_gain_states target_phase_states
            % num_measurement_points = size(measurement_points, 1);
            % 
            % if num_measurement_points < 4
            %     valid = 0;
            % else
            %     upper = imag(measurement_points(1, 1));
            %     lower = upper;
            %     left = real(measurement_points(1, 1));
            %     right = left;
            % 
            %     for k = 2:1:num_measurement_points
            %         if imag(measurement_points(k, 1)) > upper
            %             upper = imag(measurement_points(k, 1));
            %         elseif imag(measurement_points(k, 1)) < lower
            %             lower = imag(measurement_points(k, 1));
            %         end
            % 
            %         if real(measurement_points(k, 1)) < left
            %             left = real(measurement_points(k, 1));
            %         elseif real(measurement_points(k, 1)) > right
            %             right = real(measurement_points(k, 1));
            %         end
            %     end
            % 
            %     target_point = polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index));
            % 
            %     if (imag(target_point) >= lower) && (imag(target_point) <= upper) && (real(target_point) >= left) && (real(target_point) <= right)
            %         valid = 1;
            %     else
            %         valid = 0;
            %     end
            % end
        
            target_point = conversionClass.polar2cartesian(target_gain_states(Current_Calibration_Gain_Index), target_phase_states(Current_Calibration_Phase_Index));
        
            X = real(measurement_points);
            Y = imag(measurement_points);
            boundary_index = boundary(X, Y);
            num_boundary_index = size(boundary_index, 1);
        
            boundary_X = zeros(num_boundary_index, 1);
            boundary_Y = zeros(num_boundary_index, 1);
        
            for k = 1:1:num_boundary_index
                boundary_X(k, 1) = X(boundary_index(k, 1), 1);
                boundary_Y(k, 1) = Y(boundary_index(k, 1), 1);
            end
        
            valid = inpolygon(real(target_point), imag(target_point), boundary_X, boundary_Y);
        end


    end
end