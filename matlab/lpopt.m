function [x,obj,info,output,lambda,states] = lpopt(c, x0, xl, xu, A, al, au, varargin)
% function [x,obj,info,output,lambda,states] = lpopt(c, x0, xl, xu, A, al, au, varargin)
%
% This function solves the linear optimization problem:
%   minimize:
%              c'x
%   subject to:
%            xl <=  x <= xu
%            al <= Ax <= au
% where:
%  x        is the column vector of initial values of the unknowns
%  xl, xu   are the lower and upper bounds of the variables
%  c        is the linear term of the objective
%  A        is the linear constraint matrix
%  al, au   are the lower and upper bounds of the linear constraints
%
% Calling sequences:
%  [] = lpopt(c, x0, xl, xu, A, al, au)
%  [] = lpopt(c, x0, xl, xu, A, al, au, options)
%
%  [] = lpopt(c, x0, xl, xu, A, al, au, states, lambda)
%  [] = lpopt(c, x0, xl, xu, A, al, au, states, lambda, options)
%
%  [x,obj,info,output,lambda,states] = lpopt(...)
%
%
% INPUT:
%  x0       is the initial guess for x
%
%  c        is the linear term of the quadratic objective
%
%  xl, xu   are the upper and lower bounds on x
%
%  A        is the linear constraint matrix. A can be a structure, or a
%           dense or sparse matrix.
%           If A is a structure, then A is represented as a
%           sparse-by-column matrix and should  have fields:
%               A.loc -- column pointers
%               A.ind -- row indices
%               A.val -- matrix values
%
%  al, au   are the upper and lower bounds on the linear constraints A*x
%
%  options  is a struct.
%           options.name   is the problem name
%           options.start  'Cold', 'Warm'
%
% OUTPUT:
%  x        is the final point
%
%  obj      is the final objective value
%
%  info     is the exit flag returned by the solver
%
%  output   is a structure containing run information --
%           output.iterations is the total number of iterations
%           output.funcCount   is the total number of function evaluations
%
%  lambda   is a structure containing the multipliers
%           lambda.x          are for the variables
%           lambda.linear     are for the linear constraints
%
%  states   is a structure
%           states.x          are for the variables
%           states.linear     are for the linear constraints
%

solveOpt = 1;

probName = '';
start    = 'Cold';

% Deal with options.
optionsLoc = 0;
if nargin == 8 || nargin == 10,
  optionsLoc = nargin - 7;
  if isstruct(varargin{optionsLoc}),
    options = varargin{optionsLoc};
    % Name
    if isfield(options,'name'),
      probName = options.name;
    end

    % Start
    if isfield(options,'start'),
      start = options.start;
    end
  else
    optionsLoc = 0;
  end
end


if nargin == 7 || nargin == 8,
  % lpopt(c, x0, xl, xu, A, al, au)
  % lpopt(c, x0, xl, xu, A, al, au, options)

  xstate = []; xmul = [];
  astate = []; amul = [];

elseif nargin == 9 || nargin == 10,
  % lpopt(c, x0, xl, xu, A, al, au, states, lambda)
  % lpopt(c, x0, xl, xu, A, al, au, states, lambda, options)

  states = varargin{1};
  lambda = varargin{2};

  xstate = []; xmul   = [];
  astate = []; amul   = [];

  if isfield(states,'x'),
    xstate = states.x;
  end

  if isfield(lambda,'x'),
    xmul = lambda.x;
  end

  if isfield(states,'linear'),
    astate = states.linear;
  end

  if isfield(lambda,'linear'),
    amul = lambda.linear;
  end

else
  error('LPOPT:InputArgs','Wrong number of arguments in LPOPT');
end

if isempty(A),
  % Setup fake constraint matrix and bounds
  warning('LPOPT:InputArgs','No linear constraints detected; dummy constraint created');

  m = 1;
  n = numel(x0);

  neA     = 1;
  indA(1) = 1;
  valA(1) = 1.0;

  locA    = zeros(n+1,1);
  locA(1) = 1;
  locA(2:n+1) = 2;
  al = [-inf]; au = [inf];

else
  if isstruct(A),
    if isfield(A,'ind') && isfield(A,'loc') && isfield(A,'val'),
      % In sparse-by-col form
      n    = numel(x0);
      locA = colvec(A.loc,'A.loc',1,n+1);
      indA = colvec(A.ind,'A.ind',1,0);
      valA = colvec(A.val,'A.val',1,0);
      m    = max(indA);
      neA  = numel(valA);
    else
      error('LPOPT:InputArgs','Matrix must have ind, loc, and val fields')
    end

  else
    [m,n]                = size(A);
    [neA,indA,locA,valA] = crd2spr(A);
  end
end


x0  = colvec(x0,'x0',1,n);
xl  = colvec(xl,'xl',1,n);
xu  = colvec(xu,'xu',1,n);
al  = colvec(al,'al',1,m);
au  = colvec(au,'au',1,m);
c   = colvec(c,'c',1,0);

userHx = 0;
[x,obj,info,itn,y,state] = sqoptmex(solveOpt, start, probName, ...
				    m, n, userHx, c, ...
				    x0, xl, xu, xstate, xmul, ...
				    neA, indA, locA, valA, al, au, astate, amul);

% Set output
output.iterations = itn;
output.info       = info;

zero     = zeros(n,1);
states.x = state(1:n);
lambda.x = y(1:n);

if m > 0,
  states.linear = state(n+1:n+m);
  lambda.linear = y(n+1:n+m);
end
