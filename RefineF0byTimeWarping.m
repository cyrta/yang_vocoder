function [refined_f0, aperiodicity_matrix] = ...
  RefineF0byTimeWarping(x, fs, f0_initial, frame_time, n_harmonics, ...
                        mag_factor, downsample_enable)
% refine F0 using time warping
% output = ...
%   RefineF0byTimeWarping(x, fs, f0_initial, frame_time, n_harmonics, ...
%                         mag_factor, downsample_enable)
%
% Input argument
%   x : speech data
%   fs : sampling frequency (Hz)
%   f0_initial : intial estimate of F0 sequence (Hz)
%   frame_time : center location of analysis window (s)
%   n_harmonics : number of harmonic components to be used for refinement
%   mag_factor : time window stretching factor
%   downsample_enable : flag for downsampling, 1: down sampling if
%                       applicable
%
% Return value
%   aperiodicity_matrix : aperiodicity of each harmonic
%   refined_f0 : refined F0 estimate (Hz)

% Copyright 2016 Google Inc. All Rights Reserved
% Author: hidekik@google.com (Hideki Kawahara)

tt = (0:length(x) - 1)' / fs;
f0_floor = min(f0_initial);
f0_ceiling = max(f0_initial);
f0_interp = ...
  exp(interp1(frame_time, log(f0_initial), tt, 'linear', 'extrap'));
[x_on_warp_time_ax, f0_init_on_warp_ax, frame_time_on_warp_ax, ...
  time_org_on_warp_time_axis, time_on_warp_ax] = ...
  StretchTimeAxis(x, fs, tt, f0_interp, f0_floor, frame_time);
[refined_f0, spectra] = ...
  RefineF0byHarmonics(x_on_warp_time_ax(:), fs, f0_init_on_warp_ax,...
                      frame_time_on_warp_ax, n_harmonics, mag_factor, ...
                      downsample_enable);
[f0_fix_on_warp_frame, time_org_on_warp_frame] = ...
  RecoverConvertedF0(refined_f0, f0_interp, f0_floor, tt, ...
                     time_org_on_warp_time_axis, time_on_warp_ax, ...
                     frame_time_on_warp_ax);
refined_f0 = ...
  interp1(time_org_on_warp_frame, f0_fix_on_warp_frame, frame_time, ...
          'linear', 'extrap');
residual_fix_on_org_frame = ...
  interp1(time_org_on_warp_frame, spectra.residual_sgram', frame_time, ...
  'linear', 'extrap')';
n_frames = length(frame_time);
frequency_axis = spectra.frequency_axis;
bin_picker = (1:floor(fs / 2 / f0_floor)) * f0_floor;
log_aperiodicity = ...
  20 * log10(max(0.003, min(1, residual_fix_on_org_frame)));
aperiodicity_matrix = zeros(floor(fs / 2 / f0_floor), n_frames);
for ii = 1:n_frames
  aperiodicity_slice = interp1(frequency_axis, log_aperiodicity(:, ii), ...
    bin_picker, 'linear', 'extrap');
  aperiodicity_matrix(:, ii) = aperiodicity_slice(:);
end;
refined_f0 = max(f0_floor, min(f0_ceiling, refined_f0)); % safeguard
end

function [f0_fix_on_warp_frame, time_org_on_warp_frame] = ...
  RecoverConvertedF0(refined_f0, f0_interp, f0_floor, tt, ...
                     time_org_on_warp_time_axis, time_on_warp_ax, ...
                     frame_time_on_warp_ax)
stretch_rate_on_org_time = f0_interp / f0_floor;
stretch_rate_on_warp_time = ...
  interp1(tt, stretch_rate_on_org_time, time_org_on_warp_time_axis, ...
          'linear','extrap');
stretch_rate_on_warp_frame = ...
  interp1(time_on_warp_ax, stretch_rate_on_warp_time, ...
          frame_time_on_warp_ax, 'linear', 'extrap');
f0_fix_on_warp_frame = ...
  stretch_rate_on_warp_frame(:) .* refined_f0;
time_org_on_warp_frame = ...
  interp1(time_on_warp_ax, time_org_on_warp_time_axis, ...
          frame_time_on_warp_ax, 'linear', 'extrap');
end

function [x_on_warp_time_ax, f0_init_on_warp_ax, frame_time_on_warp_ax, ...
  time_org_on_warp_time_axis, time_on_warp_ax] = ...
  StretchTimeAxis(x, fs, tt, f0_interp, f0_floor, frame_time)
frame_shift = frame_time(3) - frame_time(2);
phase_org = cumsum(2 * pi * f0_interp / fs);
phase_fixed = phase_org(1):2 * pi * f0_floor / fs:phase_org(end);
time_org_on_warp_time_axis = interp1(phase_org, tt, phase_fixed);
x_on_warp_time_ax = interp1(phase_org, x, phase_fixed, 'linear', 'extrap');
frame_time_on_warp_ax = ...
  (frame_time(1):frame_shift:length(x_on_warp_time_ax) / fs)';
f0_init_on_warp_ax = f0_floor + frame_time_on_warp_ax * 0;
time_on_warp_ax = (0:1 / fs:(length(x_on_warp_time_ax) - 1) / fs)';
end
