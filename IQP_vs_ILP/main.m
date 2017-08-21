% iqp vs ilp
clear all,close all,clc;

n = 5 ;             % number of custumers(n)
k = 2;              % capacity   
v = 2*n+1;

% construct map and cost map
file = strcat('map',num2str(n),'.mat');   
if ~exist(file),
   rng('shuffle');     % random seed: shuffle
   vert = rand(2*n+1,2);
else
    load(file);
end

% cost matrix
c = zeros(v,v);
for i = 1:size(c,1)
    for j = 1:size(c,2)
        c(i,j) = norm(vert(i,:)-vert(j,:));
    end
end
% c = c + eye(v); % add identity to prevent zeros from appearing in the diagonal

% make c PSD...

for i = 1:size(c,1)
    sum_c(i) = 0;
    for j = 1:size(c,2)
        sum_c(i) = sum_c(i) + abs(c(i,j));
    end
    c(i,i) = c(i,i) + sum_c(i);
    cM(i) = c(i,i);
end
for i = 1:size(c,1)
    c(i,i) = max(cM);
end
all(eig(c)>=0)  % check if c is PSD

%% IQP
constr = [];
x = binvar(v^2,1);
for i = 1:v,
    x(v*(i-1)+1) = 0;
end
x(end-v+1:end) = [1;zeros(v-1,1)];
X = reshape(x,v,v)';
x

% construct cost function
Q = zeros(v^2,v^2);
for i = 1:v
    Q((i-1) * v + 1:(i-1) * v + v,(i-1) * v + 1:(i-1) * v + v) =c;
end
for i = 1:v-1
    Q(i*v+1:i*v+v,(i-1)*v+1:(i-1)*v+v) = c/2;
    Q((i-1)*v+1:(i-1)*v+v,i*v+1:i*v+v) = c/2;
end

Q((v-1)*v + 1:(v-1)*v + v,1:v) = c/2;
Q(1:v,(v-1)*v + 1:(v-1)*v + v) = c/2;
obj = x'*Q*x;

% d(i) = +1 (pickup), -1 (deliver)
d = [0;ones(n,1);-ones(n,1)];


% constraint: permutation matrix
for i = 1:v-1,
   constr = [constr; sum(X(i,:))==1];
   if i ~= v-1,
       constr = [constr; sum(X(:,i+1))==1];
   end
end

% constraint: capacity
L = tril(ones(v));
L(1:k,:) = [];
L(end-k+1:end,:) = [];
constr = [constr;L*X*d<=k];

% constraint: precedence
N = 1:v;
for i = 2:1+n,
   ei = zeros(v,1);
   eni = zeros(v,1);
   ei(i) = 1;
   eni(i+n) = 1;
   constr = [constr;N*X*(ei-eni)<=0];
end

% constraint: goes back to node 1 in the end
constr = [constr; X(v,1)==1];

% ops = sdpsettings('verbose',1,'solver','mosek');
ops = sdpsettings('verbose',0);
optimize(constr,obj,ops)
obj_IQP = value(obj)
solution_IQP = value(X)
tour = round(solution_IQP*[1:v]');
tour = [1;tour];
draw_tour(tour,n,vert)

%% ILP

% EXTAND c first: add enging point that equals to the starting point
temp = [0,c(1,2:end),c(1,1)];
c = blkdiag(c,c(1,1));
c(end,:) = temp;
c(:,end) = temp';

% generate decision variable x that in A. Here # of x is larger than # of
% elements in A, but those extra elements are set to be 0s.
x = binvar(v+1,v+1,'full');
x(v+1,:) = zeros(1,v+1);
x(:,1) = zeros(v+1,1);
for i = 1:v+1,
    x(i,i) = 0;
end
x

% set constraints
constr1 = [];
for i = 1:v,
    constr1 = [constr1; sum(x(:,i+1)) == 1]; % constraints w.r.t. (2)
    constr1 = [constr1; sum(x(i,:)) == 1];   % constraints w.r.t. (3)
end

% capability constraint
Q = sdpvar(v+1,1);   % decision variable for load of vehicle (really need intvar?)
q = [d;0];
for i = 1:v+1,
    for j = 1:v+1,
        if ~isnumeric(x(i,j)),
            constr1 = [constr1; implies(x(i,j),Q(j) == Q(i) + q(j))];
        end
    end
    if i~=v+1,
        constr1 = [constr1; max(0,q(i)) <= Q(i) <= min(k,k+q(i))];
    end
end

% precedence constraint
B = sdpvar(v+1,1);B(1)=0;   % decision variable for begining of service at each vertex
% construct map of t_ij (travel time from vertex i to j)
t = c; % here we assume the vehicle always travels with constant speed 1
for i = 1:v+1,
    if 2<=i && i<=n,
        constr1 = [constr1;B(i)<=B(n+i)];
    end
    for j = 1:v+1,
        if ~isnumeric(x(i,j)),
           constr1 = [constr1;implies(x(i,j),B(j)>=B(i)+t(i,j))]; 
        end
    end
end


% construct object function
obj1 = sum(sum(c.*x));

optimize(constr1,obj1,ops)
obj_ILP = value(obj1)
solution_ILP = value(x)
% construct tour
next = 1;
tour1 = 1;
while (next~=v+1),
    temp = find(solution_ILP(next,:)==1);
    tour1 = [tour1;temp];
    next = temp;
end
tour1(end) = 1;
draw_tour(tour1,n,vert)





