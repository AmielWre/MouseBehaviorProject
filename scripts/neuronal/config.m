% config.m
% Global configuration for the Computational Lab Project
% -------------------------------------------------------
% Usage:
%   cfg = config();
%
% Returns a struct with all configuration constants.

function cfg = config()

    % --- ExperimentType ---
    cfg.EXPERIMENT_TYPE = "3chamber";

    % --- Paths ---
    cfg.DATA_ROOT = fullfile("data", "processed");
    cfg.RESULTS_ROOT = fullfile("results", "neuronal");
    cfg.ML_DATASETS = fullfile("data", "ml_datasets");

    % --- Model settings ---
    cfg.MODEL_TYPES = {'logistic', 'svm'};
    cfg.SPLIT_METHOD = 'holdout';
    cfg.NORMALIZE_MODE = 'raw';  % or 'epoch'

    % --- Experimental parameters ---
    cfg.BOUNDARIES = 0:0.5:5;
    cfg.SEQ_TIMES = 0:0.5:5;
    cfg.TOP_N = 20;

    % --- Input files ---
    cfg.PS_AVERAGE_PATH = fullfile("results", "3chamber", "boundary&sequence", ...
                                   "all_groups", "average.mat");

    % --- General behavior ---
    cfg.SAVE_RESULTS = true;
end
