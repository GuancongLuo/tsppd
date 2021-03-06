% TSPPD (1-vehicle, 1-depot)
clear all;close all;clc


addpath(genpath('/opt/'));
k = 2;
n = 6;             % number of custumers(n) this needs to be divisible by the number k

q = 3;              % capacity    
rng('shuffle');     % random seed: shuffle
alph = 1;
% generate random vehicle, customer pickup and delivery locations from [0,1]x[0,1]
% vehicle node: 1
% pick-up nodes: 2,...,n+1
% delivery nodes: n+2,...,2n+1
vert = rand(2*n+k,2);
% load('matlab.mat');
v = size(vert,1);        % number of vertices |V| = 2n + 1

% cost matrix (c)
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
% for i = 1:size(c,1)
%     c(i,i) = max(cM);
% end
all(eig(c)>=0)  % check if c is PSD
% adjacency matrix for a default tour: 1->2->3->..->2n->2n+1
A0 = eye(2*n+k);
A0 = [A0(k+1:2*n+k,:);A0(1:k,:)] + alph*eye(v); % added identity to prevent zeros from appearing in the diagonal


% d(i) = +1 (pickup), -1 (deliver)
d = [zeros(k,1);ones(n,1);-ones(n,1)];

%% interger programming....


x = binvar(v^2,1);
X = reshape(x,v,v)';
xx = reshape(X,v^2,1);
%y = intvar(v,1);
% F = [Acap*xx <=bcap, Apre * xx <= bpre, X * ones(v,1)==ones(v,1),X'*ones(v,1) == ones(v,1),X(v,1) == 1];
F = [];
Lt = tril(ones(v,v));
for i = 1:k
    L{i} = zeros(v,v);
    for j = 1:n
        i;
        L{i}((j-1)*k+i,:) = Lt(j,:);
    end
end
for i = 1:length(L)
    F = [F,L{i}*X*d <= k*q];
end
F = [F, X * ones(v,1)==ones(v,1),X'*ones(v,1) == ones(v,1)];
for i = 1:k
    F = [F,X(v-i+1,k-i+1) == 1];
end
N = 1:1:v;
for i = 1:n
    eini = zeros(1,v);
    eini(i+k) = 1;
    eini(i+n+k) = -1;
    F = [F,N*X*eini' <= 0];
%    F = [F,N*X*eini' == y(i)*k];
end
% F = [Acap*x <=bcap, Apre * x < bpre, Aeq*x == beq];
% F = [];

Q = zeros(v^2,v^2);
for i = 1:v
    Q((i-1) * v + 1:(i-1) * v + v,(i-1) * v + 1:(i-1) * v + v) =c;
end
for i = 1:v-((k-1)+1)
    Q(i*v+v*(k-1)+1:i*v+v*(k-1)+v,(i-1)*v+1:(i-1)*v+v) = c/2;
    Q((i-1)*v+1:(i-1)*v+v,i*v+v*(k-1)+1:i*v+v*(k-1)+v) = c/2;
end
% 
% Q((v-1)*v + 1:(v-1)*v + v,1:v) = c/2;
% Q(1:v,(v-1)*v + 1:(v-1)*v + v) = c/2;

for i = 1:k
    Q((v-(k-i+1))*v +1:(v-(k-i+1))*v +v,(i-1)*v+1:(i-1)*v+v) = c/2;
    Q((i-1)*v+1:(i-1)*v+v,(v-(k-i+1))*v +1:(v-(k-i+1))*v +v) = c/2;
    
end



obj =x'*Q*x;
ops = sdpsettings('verbose',1);
optimize(F,obj,ops)

% generate the optimal tour from x
solution = reshape(value(xx),[size(c,1),size(c,2)]);
tour = round(solution*[1:v]');
tour = [1:k, tour']


% draw graph, and optimal tour
figure,
plot(vert(:,1),vert(:,2),'ok','MarkerSize',10,'LineWidth',2); hold on;


for i = 1:k
    for j = 1:(v-k)/k + 1
        dif = vert(tour(k*(j)+i),:)-vert(tour(k*(j-1)+i),:);
        quiver(vert(tour(k*(j-1)+i),1),vert(tour(k*(j-1)+i),2),0.1*dif(1)/norm(dif),0.1 *dif(2)/norm(dif),0, 'MaxHeadSize', 1/norm(dif),'LineWidth',2);hold on;
        line([vert(tour(k*(j-1)+i),1) vert(tour(k*(j)+i),1)],[vert(tour(k*(j-1)+i),2) vert(tour(k*(j)+i),2)],'Color','black');hold on;   
    end
end
%      dif = vert(tour(k*(i-1)+1),:)-vert(tour(k*i+1),:);
%     quiver(vert(tour(i),1),vert(tour(i),2),0.1*dif(1)/norm(dif),0.1 *dif(2)/norm(dif),0, 'MaxHeadSize', 1/norm(dif),'LineWidth',2);hold on;
%     line([vert(tour(i),1) vert(tour(i+1),1)],[vert(tour(i),2) vert(tour(i+1),2)],'Color','black');hold on;   
% % end
% for i = 1:length(tour)-1
%     dif = vert(tour(i+1),:)-vert(tour(i),:);
%     quiver(vert(tour(i),1),vert(tour(i),2),0.1*dif(1)/norm(dif),0.1 *dif(2)/norm(dif),0, 'MaxHeadSize', 1/norm(dif),'LineWidth',2);hold on;
%     line([vert(tour(i),1) vert(tour(i+1),1)],[vert(tour(i),2) vert(tour(i+1),2)],'Color','black');hold on;
% end

for i = 1:size(vert,1)
    if (mod(i-k,n)) == 0 && i > k
        prtVal = n;
    elseif i <= k
        prtVal = i;
    else
        prtVal = mod(i-k,n);
    end
    if i <=k
        str = 'th Car';
        col = 'black';
    elseif i <= n+k
        str = 'P';
        col = 'red';
    else
        str = 'D';
        col = 'blue';
    end
    text(vert(i,1)+0.02,vert(i,2)+0.02, sprintf('%.0f %s',prtVal,str),'Color',sprintf('%s',col),'FontSize',16);
end

axis('equal');
axis([0 1 0 1]);
set(gca,'FontSize',16);
% 
% % plot constraint#1
% figure,
% plot(1:v,Acap*value(xx),'bo-','MarkerSize',10,'LineWidth',2);
% hold on;
% line([0 v],[q,q],'Color','r','LineWidth',2);
% set(gca,'FontSize',16);
% xlabel('sequence');
% ylabel('# of customers in the vehicle')
% 
% % plot constraint#2
% figure,
% out = Apre*value(xx);
% 
% plot(1:n,out,'s-b','MarkerSize',10,'LineWidth',2);
% line([0 n],[0,0],'Color','r','LineWidth',2);
% set(gca,'FontSize',16);
% xlabel('custumer ID');
% ylabel('precedence')


spy(Q)
