function palm_backend(varargin)

% Take the arguments. Save a small log if needed.
global plm opts; % uncomment for debugging
[opts,plm] = palm_takeargs(varargin{:});

% To store the statistic name for each contrast, to be used later when
% saving the statistic image to a file
plm.Gname = cell(plm.nC,1);

% Variables to store stuff for later.
plm.rC           = zeros(plm.nC,1);       % to store the rank of each contrast, but can be 0 if conversion to z-stat is enabled
if opts.zstat,
    plm.rC0      = zeros(plm.nC,1);       % to store the rank of each contrast.
end
G                = cell(plm.nY,plm.nC);   % to store G at each permutation (volatile)
df2              = cell(plm.nY,plm.nC);   % to store df2 at each permutation (volatile)
Gpperm           = cell(plm.nY,plm.nC);   % counter, for the permutation p-value (volatile)
if opts.draft,
    Gppermp      = Gpperm;                % number of perms done, for the draft mode
end
plm.G            = cell(plm.nY,plm.nC);   % for the unpermutted G (and to be saved)
plm.df2          = cell(plm.nY,plm.nC);   % for the unpermutted df2 (and to be saved)
plm.Gmax         = cell(plm.nC,1);        % to store the max statistic
plm.nP           = zeros(plm.nC,1);       % number of permutations for each contrast
if opts.MV,
    Q            = cell(1,plm.nC);        % to store MV G at each permutation (volatile)
    df2q         = cell(1,plm.nC);        % to store MV df2 at each permutation (volatile)
    Qpperm       = cell(1,plm.nC);        % counter, for the MV permutation p-value (volatile)
    if opts.draft,
        Qppermp  = Qpperm;                % number of perms done, for the draft mode
    end
    plm.Qmax     = cell(plm.nC,1);        % to store the max multivariate statistic
end
if opts.NPC,
    T            = cell(1,plm.nC);        % to store T at each permutation (volatile)
    Tpperm       = cell(1,plm.nC);        % counter, for the combined p-value (volatile)
    Tzstat       = cell(1,plm.nC);        % for the combined parametric z-score (volatile)
    Tppara       = cell(1,plm.nC);        % for the combined parametric p-value (volatile)
    plm.Tmax     = cell(plm.nC,1);        % to store the max combined statistic
end
if opts.savemetrics,
    plm.metr     = cell(plm.nC,1);        % to store permutation metrics
end

% Spatial stats, univariate
if opts.clustere_t.do || opts.clustere_F.do,
    plm.checkcle = zeros(plm.nC,1);       % to store whether do cluster extent for each contrast
    plm.Gcle     = cell(plm.nY,plm.nC);   % to store cluster extent statistic
    plm.Gclemax  = cell(plm.nC,1);        % for the max cluster extent
end
if opts.clusterm_t.do || opts.clusterm_F.do,
    plm.checkclm = zeros(plm.nC,1);       % to store whether do cluster mass for each contrast
    plm.Gclm     = cell(plm.nY,plm.nC);   % to store cluster mass statistic
    plm.Gclmmax  = cell(plm.nC,1);        % for the max cluster mass
end
if opts.tfce.do,
    Gtfce        = cell(plm.nY,plm.nC);   % to store TFCE at each permutation (volatile)
    Gtfcepperm   = cell(plm.nY,plm.nC);   % counter, for the TFCE p-value (volatile)
    plm.Gtfce    = cell(plm.nY,plm.nC);   % for the unpermuted TFCE
    plm.Gtfcemax = cell(plm.nC,1);        % to store the max TFCE statistic
end

% Spatial stats, multivariate
if opts.MV && opts.clustere_mv.do,
    plm.Qcle     = cell(plm.nC,1);        % to store cluster extent NPC statistic
    plm.Qclemax  = cell(plm.nC,1);        % for the max cluster extent NPC
end
if opts.MV && opts.clusterm_mv.do,
    plm.Qclm     = cell(plm.nC,1);        % to store cluster mass NPC statistic
    plm.Qclmmax  = cell(plm.nC,1);        % for the max cluster mass NPC
end
if opts.MV && opts.tfce_mv.do,
    Qtfce        = cell(plm.nC,1);        % to store TFCE at each permutation (volatile)
    Qtfcepperm   = cell(plm.nC,1);        % counter, for the TFCE p-value (volatile)
    plm.Qtfce    = cell(plm.nC,1);        % for the unpermuted TFCE
    plm.Qtfcemax = cell(plm.nC,1);        % to store the max TFCE statistic
end

% Spatial stats, NPC
if opts.NPC && opts.clustere_npc.do,
    plm.Tcle     = cell(plm.nC,1);        % to store cluster extent NPC statistic
    plm.Tclemax  = cell(plm.nC,1);        % for the max cluster extent NPC
end
if opts.NPC && opts.clusterm_npc.do,
    plm.Tclm     = cell(plm.nC,1);        % to store cluster mass NPC statistic
    plm.Tclmmax  = cell(plm.nC,1);        % for the max cluster mass NPC
end
if opts.NPC && opts.tfce_npc.do,
    Ttfce        = cell(plm.nC,1);        % to store TFCE at each permutation (volatile)
    Ttfcepperm   = cell(plm.nC,1);        % counter, for the TFCE p-value (volatile)
    plm.Ttfce    = cell(plm.nC,1);        % for the unpermuted TFCE
    plm.Ttfcemax = cell(plm.nC,1);        % to store the max TFCE statistic
end

% For each contrast.
for c = 1:plm.nC,
    
    % Partition the model, now using the method chosen by the user
    [plm.tmp.X,plm.tmp.Z,plm.tmp.eCm,plm.tmp.eCx] = ...
        palm_partition(plm.M,plm.Cset{c},opts.pmethod);
    
    % Some methods don't work well if Z is empty, and there is no point in
    % using any of them all anyway.
    if isempty(plm.tmp.Z),
        plm.tmp.rmethod = 'noz';
    else
        plm.tmp.rmethod = opts.rmethod;
    end
        
    % Make the 3D dataset for MANOVA/MANCOVA
    if opts.MV,
        plm.tmp.Yq = cat(3,plm.Yset{:});
        plm.nYq    = plm.nY;
    else
        plm.nYq    = 1;
    end
    
    % Some other variables to be used in the function handles below.
    plm.tmp.Mp = [plm.tmp.X plm.tmp.Z]; % partitioned design matrix, joined
    plm.rC(c)  = rank(plm.tmp.eCm);     % rank(C), also df1 for all methods
    plm.tmp.rC = plm.rC(c);
    
    % Residual-forming matrix. This is used by the ter Braak method and
    % also to compute some of the stats later. Note that, even though the
    % residual-forming matrix does change at every permutation, the trace
    % for each VG remains unchanged, hence it's not necessary to recompute
    % it for every permutation, and just one works for all.
    plm.tmp.Hm  = plm.tmp.Mp*pinv(plm.tmp.Mp);
    plm.tmp.Rm  = eye(plm.N) - plm.tmp.Hm;
    plm.tmp.dRm = diag(plm.tmp.Rm); % this is used for the pivotal statistic
    plm.tmp.rM  = plm.N - round(sum(plm.tmp.dRm)); % this is faster than rank(M)
    
    % Decide which method is going to be used for the regression and
    % permutations, compute some useful matrices for later and create
    % the appropriate function handle to prepare for the model fit.
    % Each of these little functions is a replacement for the generic
    % function 'permglm.m', which is much slower.
    % Note that this swich needs to remain inside the for-loop over
    % contrasts, because the variable plm.tmp, which depends on the
    % partitioning for each contrast, is a constant for these
    % function handles.
    checkterbraak = false;
    switch lower(plm.tmp.rmethod),
        case 'noz',
            prepglm         = @(P,Y0)noz(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCx;
        case 'exact',
            prepglm         = @(P,Y0)exact(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCx;
        case 'draper-stoneman',
            prepglm         = @(P,Y0)draperstoneman(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCm;
        case 'still-white',
            plm.tmp.Rz      = eye(plm.N) - plm.tmp.Z*pinv(plm.tmp.Z);
            prepglm         = @(P,Y0)stillwhite(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCx;
        case 'freedman-lane',
            plm.tmp.Hz      = plm.tmp.Z*pinv(plm.tmp.Z);
            plm.tmp.Rz      = eye(plm.N) - plm.tmp.Hz;
            prepglm         = @(P,Y0)freedmanlane(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCm;
        case 'terbraak',
            checkterbraak   = true;
            prepglm         = @(P,Y0)terbraak(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCm;
        case 'kennedy',
            plm.tmp.Rz      = eye(plm.N) - plm.tmp.Z*pinv(plm.tmp.Z);
            prepglm         = @(P,Y0,ysel)kennedy(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCx;
        case 'manly',
            prepglm         = @(P,Y0)manly(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCm;
        case 'huh-jhun',
            plm.tmp.Rz      = eye(plm.N) - plm.tmp.Z*pinv(plm.tmp.Z);
            [plm.tmp.Q,D]   = schur(plm.tmp.Rz);
            D               = diag(D);
            D               = abs(D) > 10*eps;
            plm.tmp.Q(:,~D) = [];
            prepglm         = @(P,Y0)huhjhun(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCx;
        case 'smith',
            plm.tmp.Rz      = eye(plm.N) - plm.tmp.Z*pinv(plm.tmp.Z);
            prepglm         = @(P,Y0)smith(P,Y0,plm);
            plm.tmp.eC      = plm.tmp.eCm;
    end
    
    % Ignore or not repeated elements in the design matrix
    if opts.igrepx
        plm.tmp.seq = (1:size(plm.tmp.X,1))';
    else
        [~,~,plm.tmp.seq] = unique(plm.Xset{c},'rows');
    end
    
    % To gain in speed, choose an appropriate faster replacement for the
    % original 'pivotal.m', depending on the rank of the contrast and on
    % the presence or not of variance groups. Also define the name of the
    % statistic to save as a file later.
    if opts.pearson,
        if     plm.rC(c) == 1,
            plm.Gname{c} = 'rstat';
            fastpiv   = @(M,psi,Y)fastr(M,psi,Y,plm);
        elseif plm.rC(c) >  1,
            plm.Gname{c} = 'r2stat';
            fastpiv   = @(M,psi,Y)fastr2(M,psi,Y,plm);
        end
    else
        if     plm.rC(c) == 1 && plm.nVG == 1,
            plm.Gname{c} = 'tstat';
            fastpiv   = @(M,psi,res)fastt(M,psi,res,plm);
        elseif plm.rC(c) >  1 && plm.nVG == 1,
            plm.Gname{c} = 'fstat';
            fastpiv   = @(M,psi,res)fastf(M,psi,res,plm);
        elseif plm.rC(c) == 1 && plm.nVG >  1,
            plm.Gname{c} = 'vstat';
            fastpiv   = @(M,psi,res)fastv(M,psi,res,plm);
        elseif plm.rC(c) >  1 && plm.nVG >  1,
            plm.Gname{c} = 'gstat';
            fastpiv   = @(M,psi,res)fastg(M,psi,res,plm);
        end
        
        % Do something similar for the multivariate methods
        if opts.MV,
            if     plm.rC(c) == 1 && plm.nVG == 1,
                plm.Qname{c} = 't2stat';
                fastpivq = @(M,psi,res)fastt2(M,psi,res,plm);
            elseif plm.rC(c) >  1 && plm.nVG == 1,
                switch lower(opts.MVstat),
                    case 'wilk',
                        plm.Qname{c} = 'wilkstat';
                        plm.qfun = @(H,E)wilk(H,E);
                    case 'hotelling',
                        plm.Qname{c} = 'hotelstat';
                        plm.qfun = @(H,E)hotelling(H,E);
                    case 'pillai',
                        plm.Qname{c} = 'pillaistat';
                        plm.qfun = @(H,E)pillai(H,E);
                    case 'roy_ii',
                        plm.Qname{c} = 'roy2stat';
                        plm.qfun = @(H,E)roy_ii(H,E);
                    case 'roy_iii',
                        plm.Qname{c} = 'roy3stat';
                        plm.qfun = @(H,E)roy_iii(H,E);
                end
                fastpivq = @(M,psi,res)fastq(M,psi,res,plm);
            end
        end
    end
    
    % Choose the thresholds for the cluster-level.
    plm.checkcle(c) = false;
    plm.checkclm(c) = false;
    if     opts.clustere_t.do && plm.rC(c) == 1,
        plm.checkcle(c) = true;
        clethr = opts.clustere_t.thr;
    elseif opts.clustere_F.do && plm.rC(c) >  1,
        plm.checkcle(c) = true;
        clethr = opts.clustere_F.thr;
    end
    if     opts.clusterm_t.do && plm.rC(c) == 1,
        plm.checkclm(c) = true;
        clmthr = opts.clusterm_t.thr;
    elseif opts.clusterm_F.do && plm.rC(c) >  1,
        plm.checkclm(c) = true;
        clmthr = opts.clusterm_F.thr;
    end
    
    % Create an appropriate function handle for the NPC. As above, the
    % definition of these handles must stay inside the loop because of the
    % partitioning, which changes for every contrast.
    if opts.NPC,
        chknichols = false;
        plm.Tname = lower(opts.cmethod);
        switch plm.Tname,
            case 'tippett',
                fastnpc    = @(G,df2)tippett(G,df2,plm,c);
                pparanpc   = @(T)tippettp(T,plm);
                npcrev     = true;
            case 'fisher',
                fastnpc    = @(G,df2)fisher(G,df2,plm,c);
                pparanpc   = @(T)fisherp(T,plm);
                npcrev     = false;
            case 'pearson-david',
                fastnpc    = @(G,df2)pearsondavid(G,df2,plm,c);
                pparanpc   = @(T)pearsondavidp(T,plm);
                npcrev     = false;
            case 'stouffer',
                fastnpc    = @(G,df2)stouffer(G,df2,plm,c);
                pparanpc   = @(T)stoufferp(T);
                npcrev     = false;
            case 'wilkinson',
                fastnpc    = @(G,df2)wilkinson(G,df2,plm,c);
                pparanpc   = @(T)wilkinsonp(T,plm);
                npcrev     = false;
            case 'winer'
                fastnpc    = @(G,df2)winer(G,df2,plm,c);
                pparanpc   = @(T)winerp(T);
                npcrev     = false;
            case 'edgington',
                fastnpc    = @(G,df2)edgington(G,df2,plm,c);
                pparanpc   = @(T)edgingtonp(T,plm);
                npcrev     = true;
            case 'mudholkar-george',
                fastnpc    = @(G,df2)mudholkargeorge(G,df2,plm,c);
                pparanpc   = @(T)mudholkargeorgep(T,plm);
                npcrev     = false;
            case 'friston',
                fastnpc    = @(G,df2)fristonnichols(G,df2,plm,c);
                pparanpc   = @(T)fristonp(T,plm);
                npcrev     = true;
            case 'darlington-hayes',
                fastnpc    = @(G,df2)darlingtonhayes(G,df2,plm,c);
                npcrev     = false;
            case 'zaykin',
                fastnpc    = @(G,df2)zaykin(G,df2,plm,c);
                pparanpc   = @(T)zaykinp(T,plm);
                npcrev     = false;
            case 'dudbridge-koeleman',
                fastnpc    = @(G,df2)dudbridgekoeleman(G,df2,plm,c);
                pparanpc   = @(T)dudbridgekoelemanp(T,plm);
                npcrev     = false;
            case 'dudbridge-koeleman2',
                fastnpc    = @(G,df2)dudbridgekoeleman2(G,df2,plm,c);
                pparanpc   = @(T)dudbridgekoeleman2p(T,plm);
                npcrev     = false;
            case 'nichols',
                fastnpc    = @(G,df2)fristonnichols(G,df2,plm,c);
                pparanpc   = @(T)nicholsp(T);
                npcrev     = true;
                chknichols = true;
            case 'taylor-tibshirani',
                fastnpc    = @(G,df2)taylortibshirani(G,df2,plm,c);
                pparanpc   = @(T)taylortibshiranip(T,plm);
                npcrev     = false;
            case 'jiang',
                fastnpc    = @(G,df2)jiang(G,df2,plm,c);
                npcrev     = false;
        end
        
        % For the NPC methods in which the most significant stats
        % are the smalest, rather than the largest ones, use adequate
        % comparisons
        if npcrev,
            npcrel  = @le;
            npcextr = @min;
        else
            npcrel  = @ge;
            npcextr = @max;
        end
    end
    
    % Define the set of permutations. For ter Braak and Manly, this is
    % defined just for the 1st contrast, not for the others.
    if c == 1 || ~ any(strcmpi(opts.rmethod,{'terbraak','manly'})),
        if isempty(plm.EB),
            [plm.tmp.Pset,plm.nP(c),plm.metr{c}] = palm_shuffree(...
                plm.tmp.seq,opts.nP0,opts.CMC,opts.EE,opts.ISE,false);
        else
            [plm.tmp.Pset,plm.nP(c),plm.metr{c}] = palm_shuftree(opts,plm);
        end
    else
        plm.nP(2:end) = plm.nP(1);
    end
    
    % If the user wants to save the permutations, save the vectors now.
    % This has 3 benefits: (1) the if-test below will run just once, rather
    % than many times inside the loop, (2) if the user only wants the
    % vectors, not the images, he/she can cancel immediately after the
    % text file has been created and (3) having all just as a single big
    % file is more convenient than hundreds of small ones.
    if opts.saveperms,
        % It's faster to write directly as below than using dlmwrite and
        % palm_swapfmt.m
        fid = fopen(sprintf('%s_con%d_permidx.csv',opts.o,c),'w');
        for p = 1:plm.nP(c),
            fprintf(fid,'%d,',palm_perm2idx(plm.tmp.Pset{p})');
            fseek(fid,-1,'eof');
            fprintf(fid,'\n');
        end
        fclose(fid);
    end
    
    % If the user requests, save the permutation metrics
    if opts.savemetrics,
        fid = fopen(sprintf('%s_con%d_metrics.csv',opts.o,c),'w');
        fprintf(fid,[ ...
            'Log of max number of permutations given the tree (W),%f\n' ...
            'Log of max number of permutations if unrestricted (W0),%f\n' ...
            'Anisotropy [1-log(W)/log(W0)],%f\n' ...
            '-log(W/W0),%f\n' ...
            'Huberman & Hogg complexity (tree only),%d\n' ...
            'Huberman & Hogg complexity (tree & design),%d\n' ...
            'Average Hamming distance (tree only),%f\n' ...
            'Average Hamming distance (tree & design),%f\n'], plm.metr{c});
        fclose(fid);
    end
    
    % Some vars for later
    if checkterbraak, psi0 = cell(plm.nY,1); end
    if opts.draft,    ysel = cell(plm.nY,1); end
    plm.Gmax{c} = zeros(plm.nP(c),plm.nY);
    if plm.checkcle(c), plm.Gclemax{c}  = zeros(plm.nP(c),plm.nY); end
    if plm.checkclm(c), plm.Gclmmax{c}  = zeros(plm.nP(c),plm.nY); end
    if opts.tfce.do,    plm.Gtfcemax{c} = zeros(plm.nP(c),plm.nY); end
    if opts.clustere_npc.do, plm.Tclemax{c}  = zeros(plm.nP(c),1); end
    if opts.clusterm_npc.do, plm.Tclmmax{c}  = zeros(plm.nP(c),1); end
    if opts.tfce_npc.do,     plm.Ttfcemax{c} = zeros(plm.nP(c),1); end
    if opts.MV,
        plm.Qmax{c} = zeros(plm.nP(c),1);
    end
    if opts.NPC,
        if chknichols,
            plm.Tmax{c} = zeros(plm.nP(c),plm.nY);
        else
            plm.Tmax{c} = zeros(plm.nP(c),1);
        end
    end
    
    % For each permutation
    for p = 1:plm.nP(c),
        
        % Some feedback
        fprintf('Contrast %d/%d, Shuffling %d/%d: [ ', ...
            c,plm.nC,p,plm.nP(c));
        
        % MANOVA/MANCOVA begins here
        if opts.MV,
            fprintf('M ');
            
            % Shuffle the data and/or design.
            if opts.draft,
                if p == 1,
                    yselq = true(1,size(plm.tmp.Yq,2),1);
                end
                [M,Y] = prepglm(plm.tmp.Pset{p},plm.tmp.Yq(:,yselq,:));
            else
                [M,Y] = prepglm(plm.tmp.Pset{p},plm.tmp.Yq);
            end
            
            % Do the GLM fit. For speed, iterate over
            % modalities, not of over voxels
            psi = zeros(size(M,2),size(plm.tmp.Yq,2),plm.nYq);
            res = zeros(size(plm.tmp.Yq));
            for y = 1:plm.nYq,
                psi(:,:,y) = M\Y(:,:,y);
                res(:,:,y) = Y(:,:,y) - M*psi(:,:,y);
            end
            
            % ter Braak permutes under alternative.
            if checkterbraak,
                if p == 1,
                    psi0q = psi;
                else
                    psi = psi - psi0q;
                end
            end
            
            % Compute the pivotal multivariate statistic.
            [Q{c},df2q{c}] = fastpivq(M,psi,res);
            
            % Convert to Z if that was asked
            if opts.zstat,
                if p == 1,
                    plm.Qname{c} = 'zstat';
                end
                Q{c} = palm_gtoz(Q{c},plm.nYq,df2q{c}); % change this later to qtoz
            end
            
            % Save the unpermuted statistic
            if p == 1,
                palm_quicksave(Q{c},0,opts,plm,[],c, ...
                    sprintf('%s_%s_%s_con%d', ...
                    opts.o,plm.Ykindstr{1},plm.Qname{c},c));
            end
            
            % In the "draft" mode, the Gpperm variable isn't a counter,
            % but the number of permutations until a statistic larger than
            % the unpermuted was found.
            if opts.draft,   
                if p == 1,
                    % In the first permutation, keep Q and df2q,
                    % and start the counter.
                    plm.Q{c}    = Q{c};
                    plm.df2q{c} = df2q{c};
                    Qpperm{c}   = zeros(size(Q{c}));
                    Qppermp{c}  = zeros(size(Q{c}));
                                            
                    % Save the degrees of freedom
                    if ~ opts.zstat,
                        savedof(plm.nYq,plm.df2q{c}, ...
                            sprintf('%s_%s_%s_con%d.dof', ...
                            opts.o,plm.Ykindstr{1},plm.Qname{c},c));
                    end
                else
                    % Otherwise, store the permutation in which a larger
                    % statistic happened, and remove this voxel/vertex/face
                    % from further runs.
                    Qpperm{c}(yselq) = Qpperm{c}(yselq) + ...
                        (Q{c} >= plm.Q{c}(yselq));
                    Qppermp{c}(yselq) = p;
                    yselq = Qpperm{c} < opts.draft;
                end
            else
                
                % If the user wants to save the statistic for each
                % permutation, save it now. This isn't obviously allowed
                % in draft mode, as the images are not complete. Also,
                % this is inside the loop to allow the two-tailed option
                % not to use to much memory
                if opts.saveperms,
                    palm_quicksave(Q{c},0,opts,plm,[],c, ...
                        sprintf('%s_%s_%s_con%d_perm%06d', ...
                        opts.o,plm.Ykindstr{1},plm.Qname{c},c,p));
                end
                if p == 1,
                    % In the first permutation, keep Q and df2q,
                    % and start the counter.
                    plm.Q{c}    = Q{c};
                    plm.df2q{c} = df2q{c};
                    Qpperm{c}   = zeros(size(Q{c}));
                    
                    % Save the degrees of freedom
                    if ~ opts.zstat,
                        savedof(plm.nYq,plm.df2q{c}, ...
                            sprintf('%s_%s_%s_con%d.dof', ...
                            opts.o,plm.Ykindstr{1},plm.Qname{c},c))
                    end
                end
                Qpperm{c}      = Qpperm{c} + (Q{c} >= plm.Q{c});
                plm.Qmax{c}(p) = max(Q{c},[],2);
                
                % Cluster extent is here
                if opts.clustere_mv.do,
                    if p == 1,
                        [plm.Qclemax{c}(p),plm.Qcle{c}] = ...
                            palm_clustere(Q{c},1,opts.clustere_mv.thr,opts,plm);
                    else
                        plm.Qclemax{c}(p) = ...
                            palm_clustere(G{c},1,opts.clustere_mv.thr,opts,plm);
                    end
                end
                
                % Cluster mass is here
                if opts.clusterm_mv.do,
                    if p == 1,
                        [plm.Qclmmax{c}(p),plm.Qclm{c}] = ...
                            palm_clusterm(Q{c},1,opts.clusterm_mv.thr,opts,plm);
                    else
                        plm.Qclmmax{c}(p) = ...
                            palm_clusterm(Q{c},1,opts.clusterm_mv.thr,opts,plm);
                    end
                end
                
                % TFCE is here
                if opts.tfce_mv.do,
                    Qtfce{c} = palm_tfce(Q{c},1,opts,plm);
                    if p == 1,
                        plm.Qtfce{c} = Qtfce{c};
                        Qtfcepperm{c} = zeros(size(Q{c}));
                    end
                    Qtfcepperm{c} = Qtfcepperm{c} + ...
                        (Qtfce{c} >= plm.Qtfce{c});
                    plm.Qtfcemax{c}(p) = max(Qtfce{c},[],2);
                end
            end
        end
        
        % For each input dataset
        for y = 1:plm.nY,
            fprintf('%d ',y);
            
            % Shuffle the data and/or design.
            if opts.draft,
                if p == 1,
                    ysel{y} = true(1,size(plm.Yset{y},2));
                end
                [M,Y] = prepglm(plm.tmp.Pset{p},plm.Yset{y}(:,ysel{y}));
            else
                [M,Y] = prepglm(plm.tmp.Pset{p},plm.Yset{y});
            end
            
            % Do the GLM fit.
            psi = M\Y;
            res = Y - M*psi;
            
            % ter Braak permutes under alternative.
            if checkterbraak,
                if p == 1,
                    psi0{y} = psi;
                else
                    psi = psi - psi0{y};
                end
            end
            
            % Compute the pivotal statistic.
            if opts.pearson,
                G{y,c}   = fastpiv(M,psi,Y);
                df2{y,c} = NaN;
            else
                [G{y,c},df2{y,c}] = fastpiv(M,psi,res);
            end
            
            % Convert to Z if that was asked
            if opts.zstat,
                if p == 1 && y == 1,
                    plm.rC0(c)   = plm.rC(c);
                    plm.rC(c)    = 0;
                    plm.Gname{c} = 'zstat';
                end
                G{y,c} = palm_gtoz(G{y,c},plm.rC0(c),df2{y,c});
            end
            
            % Save the unpermuted statistic
            if p == 1,
                palm_quicksave(G{y,c},0,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_mod%d_con%d', ...
                    opts.o,plm.Ykindstr{y},plm.Gname{c},y,c));
            end
            
            % In the "draft" mode, the Gpperm variable isn't a counter,
            % but the number of permutations until a statistic larger than
            % the unpermuted was found.
            if opts.draft,
                
                % Remove the sign if this is a two-tailed test.
                if opts.twotail,
                    G{y,c} = abs(G{y,c});
                end
                
                if p == 1,
                    % In the first permutation, keep G and df2,
                    % and start the counter.
                    plm.G{y,c}   = G{y,c};
                    plm.df2{y,c} = df2{y,c};
                    Gpperm{y,c}  = zeros(size(G{y,c}));
                    Gppermp{y,c} = zeros(size(G{y,c}));
                                            
                    % Save the degrees of freedom
                    if ~ opts.zstat,
                        savedof(plm.rC(c),plm.df2{y,c}, ...
                            sprintf('%s_%s_%s_mod%d_con%d.dof', ...
                            opts.o,plm.Ykindstr{y},plm.Gname{c},y,c));
                    end
                else
                    % Otherwise, store the permutation in which a larger
                    % statistic happened, and remove this voxel/vertex/face
                    % from further runs.
                    Gpperm{y,c}(ysel{y}) = Gpperm{y,c}(ysel{y}) + ...
                        (G{y,c} >= plm.G{y,c}(ysel{y}));
                    Gppermp{y,c}(ysel{y}) = p;
                    ysel{y} = Gpperm{y,c} < opts.draft;
                end
            else
                
                % If the user wants to save the statistic for each
                % permutation, save it now. This isn't obviously allowed
                % in draft mode, as the images are not complete. Also,
                % this is inside the loop to allow the two-tailed option
                % not to use to much memory
                if opts.saveperms,
                    palm_quicksave(G{y,c},0,opts,plm,y,c, ...
                        sprintf('%s_%s_%s_mod%d_con%d_perm%06d', ...
                        opts.o,plm.Ykindstr{y},plm.Gname{c},y,c,p));
                end
                
                % Remove the sign if this is a two-tailed test.
                if opts.twotail,
                    G{y,c} = abs(G{y,c});
                end
                
                if p == 1,
                    % In the first permutation, keep G and df2,
                    % and start the counter.
                    plm.G{y,c}   = G{y,c};
                    plm.df2{y,c} = df2{y,c};
                    Gpperm{y,c}  = zeros(size(G{y,c}));
                    
                    % Save the degrees of freedom
                    if ~ opts.zstat,
                        savedof(plm.rC(c),plm.df2{y,c}, ...
                            sprintf('%s_%s_%s_mod%d_con%d.dof', ...
                            opts.o,plm.Ykindstr{y},plm.Gname{c},y,c))
                    end
                end
                Gpperm{y,c}      = Gpperm{y,c} + (G{y,c} >= plm.G{y,c});
                plm.Gmax{c}(p,y) = max(G{y,c},[],2);
                
                % Cluster extent is here
                if plm.checkcle(c),
                    if p == 1,
                        [plm.Gclemax{c}(p,y),plm.Gcle{y,c}] = ...
                            palm_clustere(G{y,c},y,clethr,opts,plm);
                    else
                        plm.Gclemax{c}(p,y) = ...
                            palm_clustere(G{y,c},y,clethr,opts,plm);
                    end
                end
                
                % Cluster mass is here
                if plm.checkclm(c),
                    if p == 1,
                        [plm.Gclmmax{c}(p,y),plm.Gclm{y,c}] = ...
                            palm_clusterm(G{y,c},y,clmthr,opts,plm);
                    else
                        plm.Gclmmax{c}(p,y) = ...
                            palm_clusterm(G{y,c},y,clmthr,opts,plm);
                    end
                end
                
                % TFCE is here
                if opts.tfce.do,
                    Gtfce{y,c} = palm_tfce(G{y,c},y,opts,plm);
                    if p == 1,
                        plm.Gtfce{y,c} = Gtfce{y,c};
                        Gtfcepperm{y,c} = zeros(size(G{y,c}));
                    end
                    Gtfcepperm{y,c} = Gtfcepperm{y,c} + ...
                        (Gtfce{y,c} >= plm.Gtfce{y,c});
                    plm.Gtfcemax{c}(p,y) = max(Gtfce{y,c},[],2);
                end
            end
        end
        
        % NPC is here
        if opts.NPC,
            fprintf('C ');
            
            % Compute the combined statistic
            Gnpc = cat(1,G{:,c});
            T{c} = fastnpc(Gnpc,cat(1,df2{:,c}));
            
            % Save the NPC Statistic (this is inside the loop because
            % of the two-tailed option)
            if p == 1,
                palm_quicksave(T{c},0,opts,plm,[],c, ...
                    sprintf('%s_%s_%s_con%d', ...
                    opts.o,plm.Ykindstr{1},'npc',c));
            end
            
            % If the user wants to save the NPC statistic for each
            % permutation, save it now.
            if opts.saveperms,
                palm_quicksave(T{c},0,opts,plm,[],c, ...
                    sprintf('%s_%s_%s_con%d_perm%06d', ...
                    opts.o,plm.Ykindstr{1},'npc',c,p));
            end
            
            % Increment counters
            if p == 1,
                plm.T{c}  = T{c};
                Tpperm{c} = zeros(size(T{c}));
            end
            if chknichols,
                Tpperm{c} = Tpperm{c} + sum( ...
                    bsxfun(npcrel,...
                    palm_gpval(Gnpc,plm.rC(c),cat(1,df2{:,c})), ...
                    plm.T{c}),1);
                plm.Tmax{c}(p,:) = npcextr(T{c},[],2)';
            else
                Tpperm{c} = Tpperm{c} + ...
                    bsxfun(npcrel,T{c},plm.T{c});
                plm.Tmax{c}(p) = npcextr(T{c},[],2);
            end
            
            % Just a feedback message for some situations.
            if p == 1                     &&   ...
                    opts.savepara         &&   ...
                    ~ plm.nonpcppara      &&   ...
                    ~ any([                    ...
                    opts.clustere_npc.do       ...
                    opts.clusterm_npc.do       ...
                    opts.tfce_npc.do]')   &&   ...
                    any(strcmpi(opts.cmethod,{ ...
                    'dudbridge-koeleman',      ...
                    'dudbridge-koeleman2'})),
                fprintf('(1st perm is slower) ');
            end
            
            % Since computing the parametric p-value for some methods
            % can be quite slow, it's faster to run all these checks
            % to ensure that 'pparanpc' runs just once.
            if any([ ...
                    opts.clustere_npc.do   ...
                    opts.clusterm_npc.do   ...
                    opts.tfce_npc.do]') || ...
                    (p == 1             && ...
                    opts.savepara       && ...
                    ~ plm.nonpcppara),
                Tppara{c} = pparanpc(T{c});
                
                % Reserve the p-parametric to save later.
                if p == 1,
                    plm.Tppara{c} = Tppara{c};
                end
            end
            
            % Now compute the NPC spatial statistics.
            if any([ ...
                    opts.clustere_npc.do   ...
                    opts.clusterm_npc.do   ...
                    opts.tfce_npc.do]'),
                
                % Convert to z-score.
                Tzstat{c} = -norminv(Tppara{c});
                
                % Cluster extent NPC is here
                if opts.clustere_npc.do,
                    if p == 1,
                        [plm.Tclemax{c}(p),plm.Tcle{c}] = ...
                            palm_clustere(Tzstat{c},1, ...
                            opts.clustere_npc.thr,opts,plm);
                    else
                        plm.Tclemax{c}(p) = ...
                            palm_clustere(Tzstat{c},1, ...
                            opts.clustere_npc.thr,opts,plm);
                    end
                end
                
                % Cluster mass NPC is here
                if opts.clusterm_npc.do,
                    if p == 1,
                        [plm.Tclmmax{c}(p),plm.Tclm{c}] = ...
                            palm_clusterm(Tzstat{c},1, ...
                            opts.clusterm_npc.thr,opts,plm);
                    else
                        plm.Tclmmax{c}(p) = ...
                            palm_clusterm(Tzstat{c},1, ...
                            opts.clusterm_npc.thr,opts,plm);
                    end
                end
                
                % TFCE NPC is here
                if opts.tfce_npc.do,
                    Ttfce{c} = palm_tfce(Tzstat{c},1,opts,plm);
                    if p == 1,
                        plm.Ttfce{c} = Ttfce{c};
                        Ttfcepperm{c} = zeros(size(Tzstat{c}));
                    end
                    Ttfcepperm{c} = Ttfcepperm{c} + ...
                        (Ttfce{c} >= plm.Ttfce{c});
                    plm.Ttfcemax{c}(p) = max(Ttfce{c},[],2);
                end
            end
        end
        fprintf(']\n');
    end
    
    % Save the statistic and the uncorrected & FWER within modality p-values.
    fprintf('Saving p-values (uncorrected and corrected within modality & contrast).\n')
    for y = 1:plm.nY,
        
        % Only permutation p-value and its FDR ajustment are saved in the
        % draft mode.
        if opts.draft,
            
            % Permutation p-value, uncorrected
            P = (Gpperm{y,c}+1)./Gppermp{y,c};
            palm_quicksave(P,1,opts,plm,y,c, ...
                sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                opts.o,plm.Ykindstr{y},plm.Gname{c},'uncp',y,c));
            
            % Permutation p-value, FDR adjusted
            if opts.FDR,
                palm_quicksave(fastfdr(P),1,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,plm.Ykindstr{y},plm.Gname{c},'fdrp',y,c));
            end
        else
            
            % Permutation p-value
            P = Gpperm{y,c}/plm.nP(c);
            palm_quicksave(P,1,opts,plm,y,c, ...
                sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                opts.o,plm.Ykindstr{y},plm.Gname{c},'uncp',y,c));
            
            % FWER-corrected within modality and contrast.
            palm_quicksave(palm_datapval( ...
                plm.G{y,c},plm.Gmax{c}(:,y),false), ...
                1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                opts.o,plm.Ykindstr{y},plm.Gname{c},'fwep',y,c));
            
            % Permutation p-value, FDR adjusted
            if opts.FDR,
                palm_quicksave(fastfdr(P),1,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,plm.Ykindstr{y},plm.Gname{c},'fdrp',y,c));
            end
            
            % Cluster extent results.
            if plm.checkcle(c),
                
                % Cluster extent statistic.
                palm_quicksave(plm.Gcle{y,c},0,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_mod%d_con%d', ...
                    opts.o,'clustere',plm.Gname{c},y,c));
                
                % Cluster extent FWER p-value
                palm_quicksave(palm_datapval( ...
                    plm.Gcle{y,c},plm.Gclemax{c}(:,y),false), ...
                    1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,'clustere',plm.Gname{c},'fwep',y,c));
            end
            
            % Cluster mass results.
            if plm.checkclm(c),
                
                % Cluster mass statistic.
                palm_quicksave(plm.Gclm{y,c},0,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_mod%d_con%d', ...
                    opts.o,'clusterm',plm.Gname{c},y,c));
                
                % Cluster mass FWER p-value.
                palm_quicksave(palm_datapval( ...
                    plm.Gclm{y,c},plm.Gclmmax{c}(:,y),false), ...
                    1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,'clusterm',plm.Gname{c},'fwep',y,c));
            end
            
            % TFCE results
            if opts.tfce.do,
                
                % TFCE statistic
                palm_quicksave(plm.Gtfce{y,c},0,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_mod%d_con%d', ...
                    opts.o,'tfce',plm.Gname{c},y,c));
                
                % TFCE p-value
                P = Gtfcepperm{y,c}/plm.nP(c);
                palm_quicksave(P,1,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,'tfce',plm.Gname{c},'uncp',y,c));
                
                % TFCE FWER-corrected within modality and contrast.
                palm_quicksave(palm_datapval( ...
                    plm.Gtfce{y,c},plm.Gtfcemax{c}(:,y),false), ...
                    1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,'tfce',plm.Gname{c},'fwep',y,c));
                
                % TFCE p-value, FDR adjusted.
                if opts.FDR,
                    palm_quicksave(fastfdr(P),1,opts,plm,y,c, ...
                        sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'tfce',plm.Gname{c},'fdrp',y,c));
                end
            end
        end
        
        % Parametric p-value and its FDR adjustment
        if opts.savepara,
            P = palm_quicksave(plm.G{y,c},2, ...
                opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                opts.o,plm.Ykindstr{y},plm.Gname{c},'uncparap',y,c));
            if opts.FDR,
                palm_quicksave(fastfdr(P),1,opts,plm,y,c, ...
                    sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,plm.Ykindstr{y},plm.Gname{c},'fdrparap',y,c));
            end
        end
    end
    
    % Save the NPC results for this contrast
    if opts.NPC,
        fprintf('Saving NPC p-values (uncorrected and corrected within contrast).\n')
        
        % For the Nichols method, the maxima for all modalities are pooled
        if chknichols,
            plm.Tmax{c} = plm.Tmax{c}(:);
        end
        
        % NPC p-value
        P = Tpperm{c}/numel(plm.Tmax{c});
        palm_quicksave(P,1,opts,plm,[],c, ...
            sprintf('%s_%s_%s_%s_con%d', ...
            opts.o,plm.Ykindstr{1},'npc','uncp',c));
        
        % NPC FWER-corrected within modality and contrast.
        palm_quicksave(palm_datapval(plm.T{c},plm.Tmax{c},npcrev), ...
            1,opts,plm,[],c,sprintf('%s_%s_%s_%s_con%d', ...
            opts.o,plm.Ykindstr{1},'npc','fwep',c));
        
        % NPC FDR
        if opts.FDR,
            palm_quicksave(fastfdr(P),1,opts,plm,[],c, ...
                sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,plm.Ykindstr{1},'npc','fdrp',c));
        end
        
        % Parametric combined pvalue
        if opts.savepara && ~ plm.nonpcppara,
            palm_quicksave(plm.Tppara{c},1,opts,plm,[],c, ...
                sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,plm.Ykindstr{1},'npc','uncparap',c));
        end
        
        % Cluster extent NPC results.
        if opts.clustere_npc.do,
            
            % Cluster extent statistic.
            palm_quicksave(plm.Tcle{c},0,opts,plm,[],c, ...
                sprintf('%s_%s_%s_con%d', ...
                opts.o,'clustere','npc',c));
            
            % Cluster extent FWER p-value
            palm_quicksave(palm_datapval( ...
                plm.Tcle{c},plm.Tclemax{c},false), ...
                1,opts,plm,y,c,sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,'clustere','npc','fwep',c));
        end
        
        % Cluster mass NPC results.
        if opts.clusterm_npc.do,
            
            % Cluster mass statistic.
            palm_quicksave(plm.Tclm{c},0,opts,plm,[],c, ...
                sprintf('%s_%s_%s_con%d', ...
                opts.o,'clusterm','npc',c));
            
            % Cluster mass FWER p-value
            palm_quicksave(palm_datapval( ...
                plm.Tclm{c},plm.Tclmmax{c},false), ...
                1,opts,plm,y,c,sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,'clusterm','npc','fwep',c));
        end
        
        % TFCE NPC results.
        if opts.tfce_npc.do,
            
            % TFCE statistic.
            palm_quicksave(plm.Ttfce{c},0,opts,plm,[],c, ...
                sprintf('%s_%s_%s_con%d', ...
                opts.o,'tfce','npc',c));
            
            % TFCE FWER p-value
            palm_quicksave(palm_datapval( ...
                plm.Ttfce{c},plm.Ttfcemax{c},false), ...
                1,opts,plm,y,c,sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,'tfce','npc','fwep',c));
        end
    end
end

% Free up some memory after the loop.
clear M Y psi res G df2 Gpperm T Tpperm Tppara Tzstat Ttfce;

% Save FWER corrected across modalities.
if opts.corrmod,
    fprintf('Saving p-values (corrected across modalities).\n')
    for c = 1:plm.nC,
        distmax = max(plm.Gmax{c},[],2);
        for y = 1:plm.nY,
            palm_quicksave(palm_datapval(plm.G{y,c},distmax,false), ...
                1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                opts.o,plm.Ykindstr{y},plm.Gname{c},'fwemp',y,c));
        end
    end
    
    % Cluster extent
    if all(plm.Yisvol) || all(plm.Yissrf),
        for c = 1:plm.nC,
            if plm.checkcle(c),
                distmax = max(plm.Gclemax{c},[],2);
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval(plm.Gcle{y,c},distmax,false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'clustere',plm.Gname{c},'fwemp',y,c));
                end
            end
        end
    end
    
    % Cluster mass
    if all(plm.Yisvol) || all(plm.Yissrf),
        for c = 1:plm.nC,
            if plm.checkclm(c),
                distmax = max(plm.Gclmmax{c},[],2);
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval(plm.Gclm{y,c},distmax,false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'clusterm',plm.Gname{c},'fwemp',y,c));
                end
            end
        end
    end
    
    % TFCE
    if opts.tfce.do && (all(plm.Yisvol) || all(plm.Yissrf)),
        for c = 1:plm.nC,
            distmax = max(plm.Gtfcemax{c},[],2);
            for y = 1:plm.nY,
                palm_quicksave(palm_datapval(plm.Gtfce{y,c},distmax,false), ...
                    1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,'tfce',plm.Gname{c},'fwemp',y,c));
            end
        end
    end
end

% Save FWER corrected across contrasts.
if opts.corrcon,
    fprintf('Saving p-values (corrected across contrasts).\n');
    
    % Ranks of the contrasts
    Urc = unique(plm.rC);
    nUrc = numel(Urc);
    
    % Vars for below, before the loop
    plm.rGmax = cell(nUrc,1);
    if all(plm.checkcle) && ...
            (all(plm.Yisvol) || all(plm.Yissrf)),
        plm.rGclemax = plm.rGmax;
    end
    if all(plm.checkclm) && ...
            (all(plm.Yisvol) || all(plm.Yissrf)),
        plm.rGclmmax = plm.rGmax;
    end
    if opts.tfce.do && ...
            (all(plm.Yisvol) || all(plm.Yissrf)),
        plm.rGtfcemax = plm.rGmax;
    end
    
    % For each contrast rank
    for rc = 1:nUrc,
        
        % Element wise correction
        plm.rGmax{rc} = cat(3,plm.Gmax{plm.rC == Urc(rc)});
        distmax = max(plm.rGmax{rc},[],3);
        for c = 1:plm.nC,
            for y = 1:plm.nY,
                palm_quicksave(palm_datapval( ...
                    plm.G{y,c},distmax(:,y),false), ...
                    1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,plm.Ykindstr{y},plm.Gname{c},'fwecp',y,c));
            end
        end
        
        % Cluster extent
        if all(plm.checkcle) && ...
                (all(plm.Yisvol) || all(plm.Yissrf)),
            plm.rGclemax{rc} = cat(3,plm.Gclemax{plm.rC == Urc(rc)});
            distmax = max(plm.rGclemax{rc},[],3);
            for c = 1:plm.nC,
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval( ...
                        plm.Gcle{y,c},distmax(:,y),false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'clustere',plm.Gname{c},'fwecp',y,c));
                end
            end
        end
        
        % Cluster mass
        if all(plm.checkclm) && ...
                (all(plm.Yisvol) || all(plm.Yissrf)),
            plm.rGclmmax{rc} = cat(3,plm.Gclmmax{plm.rC == Urc(rc)});
            distmax = max(plm.rGclmmax{rc},[],3);
            for c = 1:plm.nC,
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval( ...
                        plm.Gclm{y,c},distmax(:,y),false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'clusterm',plm.Gname{c},'fwecp',y,c));
                end
            end
        end
        
        % TFCE
        if opts.tfce.do && ...
                (all(plm.Yisvol) || all(plm.Yissrf)),
            plm.rGtfcemax{rc} = cat(3,plm.Gtfcemax{plm.rC == Urc(rc)});
            distmax = max(plm.Gtfcemax{rc},[],3);
            for c = 1:plm.nC,
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval( ...
                        plm.Gtfce{y,c},distmax(:,y),false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'tfce',plm.Gname{c},'fwecp',y,c));
                end
            end
        end
    end
end

% Save FWER corrected across modalities and contrasts.
if opts.corrmod && opts.corrcon,
    fprintf('Saving p-values (corrected across modalities and contrasts).\n')
    
    % For each contrast rank
    for rc = 1:nUrc,
        
        % Element wise correction
        distmax = max(max(plm.rGmax{rc},[],3),[],2);
        for c = 1:plm.nC,
            for y = 1:plm.nY,
                palm_quicksave(palm_datapval(plm.G{y,c},distmax,false), ...
                    1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                    opts.o,plm.Ykindstr{y},plm.Gname{c},'fwecmp',y,c));
            end
        end
        
        % Cluster extent
        if all(plm.checkcle) && ...
                (all(plm.Yisvol) || all(plm.Yissrf)),
            distmax = max(max(plm.rGclemax{rc},[],3),[],2);
            for c = 1:plm.nC,
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval(plm.Gcle{y,c},distmax,false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'clustere',plm.Gname{c},'fwecmp',y,c));
                end
            end
        end
        
        % Cluster mass
        if all(plm.checkclm) && ...
                (all(plm.Yisvol) || all(plm.Yissrf)),
            distmax = max(max(plm.rGclmmax{rc},[],3),[],2);
            for c = 1:plm.nC,
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval(plm.Gclm{y,c},distmax,false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'clusterm',plm.Gname{c},'fwecmp',y,c));
                end
            end
        end
        
        % TFCE
        if opts.tfce.do && ...
                (all(plm.Yisvol) || all(plm.Yissrf)),
            distmax = max(max(plm.rGtfcemax{rc},[],3),[],2);
            for c = 1:plm.nC,
                for y = 1:plm.nY,
                    palm_quicksave(palm_datapval(plm.Gtfce{y,c},distmax,false), ...
                        1,opts,plm,y,c,sprintf('%s_%s_%s_%s_mod%d_con%d', ...
                        opts.o,'tfce',plm.Gname{c},'fwecmp',y,c));
                end
            end
        end
    end
end

% Save FWER corrected across contrasts for NPC.
if opts.NPC && opts.corrcon,
    fprintf('Saving NPC p-values (corrected across contrasts).\n')
    plm.Tmax = cat(2,plm.Tmax{:});
    distmax = max(plm.Tmax,[],2);
    for c = 1:plm.nC,
        palm_quicksave(palm_datapval(plm.T{c},distmax,npcrev), ...
            1,opts,plm,[],c,sprintf('%s_%s_%s_%s_con%d', ...
            opts.o,plm.Ykindstr{1},'npc','fwecp',c));
    end
    
    % Cluster extent NPC
    if opts.clustere_npc.do,
        plm.Tclemax = cat(3,plm.Tclemax{:});
        distmax = max(plm.Tclemax,[],3);
        for c = 1:plm.nC,
            palm_quicksave(palm_datapval(plm.Tcle{c},distmax,false), ...
                1,opts,plm,[],c,sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,'clustere','npc','fwecp',c));
        end
    end
    
    % Cluster mass NPC
    if opts.clusterm_npc.do,
        plm.Tclmmax = cat(3,plm.Tclmmax{:});
        distmax = max(plm.Tclmmax,[],3);
        for c = 1:plm.nC,
            palm_quicksave(palm_datapval(plm.Tclm{c},distmax,false), ...
                1,opts,plm,[],c,sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,'clusterm','npc','fwecp',c));
        end
    end
    
    % TFCE NPC
    if opts.tfce_npc.do,
        plm.Ttfcemax = cat(3,plm.Ttfcemax{:});
        distmax = max(plm.Ttfcemax,[],3);
        for c = 1:plm.nC,
            palm_quicksave(palm_datapval(plm.Ttfce{c},distmax,false), ...
                1,opts,plm,[],c,sprintf('%s_%s_%s_%s_con%d', ...
                opts.o,'tfce','npc','fwecp',c));
        end
    end
end

% ==============================================================
% Below are the functions for each of the regression methods:
% ==============================================================

function [Mr,Y] = noz(P,Y,plm)
% This is the same as Draper-Stoneman
% Y remains unchanged
Mr = P*plm.tmp.X;

function [Mr,Yr] = exact(P,Y,plm)
% The "exact" method, in which the coefficients for
% the nuisance are known.
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = Y(:,:,y) - plm.tmp.Z*plm.g;
    end
else
    Yr = Y - plm.tmp.Z*plm.g;
end
Mr = P*plm.tmp.X;

function [Mr,Y] = draperstoneman(P,Y,plm)
% Draper and Stoneman (1966) method.
% Y remains unchanged
Mr = [P*plm.tmp.X plm.tmp.Z];

function [Mr,Yr] = stillwhite(P,Y,plm)
% A method following the same logic as the one
% proposed by Still and White (1981)
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = plm.tmp.Rz*Y(:,:,y);
    end
else
    Yr = plm.tmp.Rz*Y;
end
Mr = P*plm.tmp.X;

function [Mr,Yr] = freedmanlane(P,Y,plm)
% The Freedman and Lane (1983) method.
Mr = [plm.tmp.X plm.tmp.Z];
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = (P'*plm.tmp.Rz + plm.tmp.Hz)*Y(:,:,y);
    end
else
    Yr = (P'*plm.tmp.Rz + plm.tmp.Hz)*Y;
end

function [Mr,Yr] = manly(P,Y,plm)
% The Manly (1986) method.
Mr = [plm.tmp.X plm.tmp.Z];
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = P'*Y(:,:,y);
    end
else
    Yr = P'*Y;
end

function [Mr,Yr] = terbraak(P,Y,plm)
% The ter Braak (1992) method.
Mr = [plm.tmp.X plm.tmp.Z];
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = (P'*plm.tmp.Rm + plm.tmp.Hm)*Y(:,:,y);
    end
else
    Yr = (P'*plm.tmp.Rm + plm.tmp.Hm)*Y; % original method
    % Yr = P'*plm.tmp.Rm*Y; % alternative (causes unpermuted statistic to be 0)
end

function [Mr,Yr] = kennedy(P,Y,plm)
% The Kennedy (1996) method. This method should NEVER be used.
Mr = plm.tmp.Rz*plm.tmp.X;
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = P'*plm.tmp.Rz*Y(:,:,y);
    end
else
    Yr = P'*plm.tmp.Rz*Y;
end

function [Mr,Yr] = huhjhun(P,Y,plm)
% The Huh and Jhun (2001) method, that fixes the issues
% with Kennedy's, but doesn't allow block permutation.
Mr = plm.tmp.Q'*plm.tmp.Rz*plm.tmp.X;
if plm.nYq > 1,
    Yr = zeros(size(Y));
    for y = 1:plm.nYq;
        Yr(:,:,y) = P'*plm.tmp.Q'*plm.tmp.Rz*Y(:,:,y);
    end
else
    Yr = P'*plm.tmp.Q'*plm.tmp.Rz*Y;
end

function [Mr,Y] = smith(P,Y,plm)
% The Smith method, i.e., orthogonalization.
% Y remains unchanged
Mr = [P*plm.tmp.Rz*plm.tmp.X plm.tmp.Z];

% ==============================================================
% Below are the functions to compute the pivotal statistics:
% ==============================================================
function G = fastr(M,psi,Y,plm)
% This only works if:
% - M and Y have zero mean.
% - rank(contrast) = 1
% 
% Inputs:
% M   : design matrix (demeaned)
% psi : regression coefficients
% Y   : data (demeaned)
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% G   : Pearson's correlation coefficient (r).

G = fastr2(M,psi,Y,plm);
G = sign(psi).*G.^.5;

% ==============================================================
function G = fastr2(M,psi,Y,plm)
% This only works if:
% - M and Y have zero mean.
% 
% Inputs:
% M   : design matrix (demeaned)
% psi : regression coefficients
% Y   : data (demeaned)
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% G   : R^2, i.e., the coefficient of determination.

tmp = plm.tmp.eC/(plm.tmp.eC'/(M'*M)*plm.tmp.eC)*plm.tmp.eC';
G   = sum((tmp'*psi).*psi,1);
den = sum(Y.^2,1);
G   = G./den;

% ==============================================================
function [G,df2] = fastt(M,psi,res,plm)
% This works only if:
% - rank(contrast) = 1
% - number of variance groups = 1
%
% Inputs:
% M   : design matrix
% psi : regression coefficients
% res : residuals
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% G   : t statistic.
% df2 : Degrees of freedom. df1 is 1 for the t statistic.

df2 = plm.N-plm.tmp.rM;
G   = plm.tmp.eC'*psi;
den = sqrt(plm.tmp.eC'/(M'*M)*plm.tmp.eC*sum(res.^2)./df2);
G   = G./den;

% ==============================================================
function [G,df2] = fastf(M,psi,res,plm)
% This works only if:
% - rank(contrast) > 1
% - number of variance groups = 1
%
% Inputs:
% M   : design matrix
% psi : regression coefficients
% res : residuals
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% G   : F-statistic.
% df2 : Degrees of freedom 2. df1 is rank(C).

df2 = plm.N-plm.tmp.rM;
cte = plm.tmp.eC/(plm.tmp.eC'/(M'*M)*plm.tmp.eC)*plm.tmp.eC';
tmp = zeros(size(psi));
for j = 1:size(cte,2),
    tmp(j,:) = sum(bsxfun(@times,psi,cte(:,j)))';
end
G   = sum(tmp.*psi);
ete = sum(res.^2);
G   = G./ete*df2/plm.tmp.rC;

% ==============================================================
function [G,df2] = fastv(M,psi,res,plm)
% This works only if:
% - rank(contrast) = 1
% - number of variance groups > 1
%
% Inputs:
% M   : design matrix
% psi : regression coefficients
% res : residuals
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% G   : Aspin-Welch v statistic.
% df2 : Degrees of freedom 2. df1 is 1.

r = size(M,2);
m = size(res,2);

W = zeros(plm.nVG,m);
dRmb = zeros(plm.nVG,1);
cte = zeros(r^2,m);
for b = 1:plm.nVG,
    bidx = plm.VG == b;
    dRmb(b) = sum(plm.tmp.dRm(bidx));
    W(b,:) = dRmb(b)./sum(res(bidx,:).^2);
    Mb = M(bidx,:)'*M(bidx,:);
    cte = cte + Mb(:)*W(b,:);
    W(b,:) = W(b,:)*sum(bidx);
end

den = zeros(1,m);
for j = 1:m,
    den(j) = plm.tmp.eC'/(reshape(cte(:,j),[r r]))*plm.tmp.eC;
end
G = plm.tmp.eC'*psi./sqrt(den);

bsum = zeros(1,m);
sW1 = sum(W,1);
for b = 1:plm.nVG,
    bsum = bsum + bsxfun(@rdivide,(1-W(b,:)./sW1).^2,dRmb(b));
end
df2 = 1/3./bsum;

% ==============================================================
function [G,df2] = fastg(M,psi,res,plm)
% This works only if:
% - rank(contrast) > 1
% - number of variance groups > 1
%
% Inputs:
% M   : design matrix
% psi : regression coefficients
% res : residuals
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% G   : Welch v^2 statistic.
% df2 : Degrees of freedom 2. df1 is rank(C).

r = size(M,2);
m = size(res,2);

W    = zeros(plm.nVG,m);
dRmb = zeros(plm.nVG,1);
cte  = zeros(r^2,m);
for b = 1:plm.nVG,
    bidx    = plm.VG == b;
    dRmb(b) = sum(plm.tmp.dRm(bidx));
    W(b,:)  = dRmb(b)./sum(res(bidx,:).^2);
    Mb      = M(bidx,:)'*M(bidx,:);
    cte     = cte + Mb(:)*W(b,:);
    W(b,:)  = W(b,:)*sum(bidx);
end

G = zeros(1,m);
for t = 1:m,
    A = psi(:,t)'*plm.tmp.eC;
    G(t) = A/(plm.tmp.eC'/(reshape(cte(:,t),[r r]))* ...
        plm.tmp.eC)*A'/plm.tmp.rC;
end

bsum = zeros(1,m);
sW1  = sum(W,1);
for b = 1:plm.nVG,
    bsum = bsum + bsxfun(@rdivide,(1-W(b,:)./sW1).^2,dRmb(b));
end
bsum = bsum/plm.tmp.rC/(plm.tmp.rC+2);
df2  = 1/3./bsum;
G    = G./(1 + 2*(plm.tmp.rC-1).*bsum);

% ==============================================================
function [Q,df2q] = fastt2(M,psi,res,plm)
% This works only if:
% - rank(contrast) = 1
% - number of variance groups = 1
% - psi and res are 3D
%
% Inputs:
% M   : design matrix
% psi : regression coefficients
% res : residuals
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% Q    : Hotelling's T^2 statistic.
% df2q : Degrees of freedom to look up in an F-distribution.
%        The df1 is plm.nYq.

nT  = size(res,2);
df0 = plm.N-plm.tmp.rM;
df2q = (df0-plm.nYq+1)/plm.nYq/df0;
cte1 = zeros(nT,plm.nYq);
for y = 1:plm.nYq,
    cte1(:,y) = plm.tmp.eC'*psi(:,:,y);
end
cte2 = plm.tmp.eC'/(M'*M)*plm.tmp.eC;
S = spr(res)/df0;
Q = zeros(1,nT);
for t = 1:nT,
    Q(1,t) = cte1(t,:)/S(:,:,t)/cte2*cte1(t,:)';
end

% ==============================================================
function [Q,df2q] = fastq(M,psi,res,plm)
% This works only if:
% - rank(contrast) > 1
% - number of variance groups = 1
% - psi and res are 3D
%
% Inputs:
% M   : design matrix
% psi : regression coefficients
% res : residuals
% plm : a struct with many things as generated by
%       'palm_backend.m' and 'palm_takeargs.m'
%
% Outputs:
% Q    : Multivariate (yet scalar) statistic.
% df2q : The parametric approximations are't quite generalisable,
%        so the df2 here is returned as empty, [].

nT   = size(res,2);
psi  = permute(psi,[1 3 2]);
cte2 = plm.tmp.eC'/(M'*M)*plm.tmp.eC;
E    = spr(res);
Q    = zeros(1,nT);
for t = 1:nT,
    cte1   = psi(:,:,t)'*plm.tmp.eC;
    H      = cte1/cte2*cte1';
    Q(1,t) = plm.qfun(E(:,:,t),H);
end
df2q = [];

% ==============================================================
% Below are the functions to combine multivariate statistics:
% ==============================================================
function Q = wilk(E,H)
% Wilk's Lambda.
Q = det(E)/det(E+H);

% ==============================================================
function Q = hotelling(E,H)
% Lawley-Hotelling's trace.
Q = trace(H/E);

% ==============================================================
function Q = pillai(E,H)
% Pillai's trace.
Q = trace(H/(E+H));

% ==============================================================
function Q = roy_ii(E,H)
% Roy's (ii) largest root (analogous to F).
Q = max(eig(H/E));

% ==============================================================
function Q = roy_iii(E,H)
% Roy's (iii) largest root (analogous to R^2).
Q = max(eig(H/(E+H)));

% ==============================================================
% Below are the functions to combine statistics:
% ==============================================================
% See the original combine.m for commented lines on implementation

function T = tippett(G,df2,plm,c)
T = min(palm_gpval(G,plm.rC(c),df2),[],1);

function P = tippettp(T,plm)
%P = T.^plm.nY;
% Note it can't be simply P = 1-(1-T)^K when implementing because
% precision is lost if the original T is smaller than eps, something
% quite common. Hence the need for the Pascal triangle, etc.
pw  = (plm.nY:-1:1);
C   = pascaltri(plm.nY);
sgn = (-1)*(-1)^pw;
P   = sum(sgn.*C.*(T.^pw));

% ==============================================================
function T = fisher(G,df2,plm,c)
T = -2*sum(log(palm_gpval(G,plm.rC(c),df2)),1);

function P = fisherp(T,plm)
P = palm_gpval(T,-1,2*plm.nY);

% ==============================================================
function T = pearsondavid(G,df2,plm,c)
T = -2*min(...
    sum(log(palm_gpval(G,plm.rC(c),df2)),1),...
    sum(log(palm_gcdf(G,plm.rC(c),df2)),1));

function P = pearsondavidp(T,plm)
P = palm_gpval(T,-1,2*plm.nY);

% ==============================================================
function T = stouffer(G,df2,plm,c)
T = sum(palm_gtoz(G,plm.rC(c),df2))/sqrt(plm.nY);

function P = stoufferp(T)
P = normcdf(-T);

% ==============================================================
function T = wilkinson(G,df2,plm,c)
T = sum(palm_gpval(G,plm.rC(c),df2) <= plm.npcparm);

function P = wilkinsonp(T,plm)
lfac    = palm_factorial(plm.nY);
lalpha  = log(plm.npcparm);
l1alpha = log(1-plm.npcparm);
P = zeros(size(T));
for k = 1:plm.nY,
    lp1 = lfac(plm.nY+1) - lfac(k+1) - lfac(plm.nY-k+1);
    lp2 = k*lalpha;
    lp3 = (plm.nY-k)*l1alpha;
    P = P + (k>=T).*exp(lp1+lp2+lp3);
end

% ==============================================================
function T = winer(G,df2,plm,c)
df2 = bsxfun(@times,ones(size(G)),df2);
cte = sqrt(sum(df2./(df2-2),1));
T   = -sum(tinv(palm_gpval(G,plm.rC(c),df2),df2))./cte;

function P = winerp(T)
P = normcdf(-T);

% ==============================================================
function T = edgington(G,df2,plm,c)
T = sum(palm_gpval(G,plm.rC(c),df2),1);

function P = edgingtonp(T,plm)
lfac = palm_factorial(plm.nY);
fT   = floor(T);
mxfT = max(fT(:));
P = zeros(size(T));
for j = 0:mxfT,
    p1  = (-1)^j;
    lp2 = - lfac(j+1) - lfac(plm.nY-j+1);
    lp3 = plm.nY*log(T-j);
    P = P + (j<=fT).*p1.*exp(lp2+lp3);
end

% ==============================================================
function T = mudholkargeorge(G,df2,plm,c)
mhcte = sqrt(3*(5*plm.nY+4)/plm.nY/(5*plm.nY+2))/pi;
T = mhcte*sum(log(...
    palm_gcdf(G,plm.rC(c),df2)./...
    palm_gpval(G,plm.rC(c),df2)),1);

function P = mudholkargeorgep(T,plm)
P = tcdf(T,5*plm.nY+4);

% ==============================================================
function T = fristonnichols(G,df2,plm,c)
T = max(palm_gpval(G,plm.rC(c),df2),[],1);

function P = fristonp(T,plm)
P = T.^(plm.nY - plm.npcparm + 1);

function T = nicholsp(T)
% T itself is P, so there is nothing to do.

% ==============================================================
function T = darlingtonhayes(G,df2,plm,c)
df2     = bsxfun(@times,ones(size(G)),df2);
[~,tmp] = sort(G,1,'descend');
[~,tmp] = sort(tmp);
idx     = tmp <= plm.npcparm;
G       = reshape(G(idx),  [plm.npcparm size(G,2)]);
df2     = reshape(df2(idx),[plm.npcparm size(df2,2)]);
P       = palm_gcdf(G,plm.rC(c),df2);
Z       = norminv(P);
T       = mean(Z,1);

% ==============================================================
function T = zaykin(G,df2,plm,c)
P = -log10(palm_gpval(G,plm.rC(c),df2));
P(P < -log10(plm.npcparm)) = 0;
T = sum(P,1);

function P = zaykinp(T,plm)
lT = -T;
lfac     = palm_factorial(plm.nY);
lalpha   = log10(plm.npcparm);
l1alpha  = log10(1-plm.npcparm);
P = zeros(size(lT));
for k = 1:plm.nY,
    lp1 = lfac(plm.nY+1) - lfac(k+1) - lfac(plm.nY-k+1);
    lp2 = (plm.nY-k)*l1alpha;
    Tsmall = lT <= k*lalpha;
    Tlarge = ~ Tsmall;
    p3 = 0;
    lnum = log10(k*lalpha - lT(Tsmall));
    for j = 1:k,
        p3 = p3 + 10.^(lT(Tsmall) + (j-1).*lnum - lfac(j));
    end
    lp3small = log10(p3);
    lp3large = k*lalpha;
    P(Tsmall) = P(Tsmall) + 10.^(lp1 + lp2 + lp3small);
    P(Tlarge) = P(Tlarge) + 10.^(lp1 + lp2 + lp3large);
end

% ==============================================================
function T = dudbridgekoeleman(G,df2,plm,c)
df2     = bsxfun(@times,ones(size(G)),df2);
[~,tmp] = sort(G,1,'descend');
[~,tmp] = sort(tmp);
idx     = tmp <= plm.npcparm;
G       = reshape(G(idx),  [plm.npcparm size(G,2)]);
df2     = reshape(df2(idx),[plm.npcparm size(df2,2)]);
P       = -log10(palm_gpval(G,plm.rC(c),df2));
T       = sum(P,1);

function P = dudbridgekoelemanp(T,plm)
lT = -T;
lfac = palm_factorial(plm.nY);
P    = zeros(size(lT));
lp1  = lfac(plm.nY+1) -        ...
    lfac(plm.npcparm+2) -      ...
    lfac(plm.nY-plm.npcparm) + ...
    log10(plm.npcparm+2);
for v = 1:numel(lT);
    P(v) = quad(@(t)dkint(t,lp1,lT(v),plm.nY,...
        plm.npcparm,lfac(1:plm.npcparm)),eps,1);
end

function T = dudbridgekoeleman2(G,df2,plm,c)
df2 = bsxfun(@times,ones(size(G)),df2);
P = -log10(palm_gpval(G,plm.rC(c),df2));
[~,tmp] = sort(G,1,'descend');
[~,tmp] = sort(tmp);
P(tmp > plm.npcparm) = 0;
P(P < -log10(plm.npcparm2)) = 0;
T = sum(P,1);

function P = dudbridgekoeleman2p(T,plm)
lT = -T;
lfac = palm_factorial(plm.nY);
P    = zeros(1,size(T,2));
for k = 1:plm.npcparm,
    kk = (plm.nY-k)*log(1-plm.npcparm2);
    if isnan(kk), kk = 0; end
    p1 = exp(lfac(plm.nY+1) - lfac(k+1) - lfac(plm.nY-k+1) + kk);
    p2 = awtk(lT,plm.npcparm2,k,lfac(1:k));
    P = P + p1.*p2;
end
if k < plm.nY,
    lp1 = lfac(plm.nY+1) -         ...
        lfac(plm.npcparm+2) -      ...
        lfac(plm.nY-plm.npcparm) + ...
        log(plm.npcparm+2);
    for v = 1:numel(lT);
        P(v) = P(v) + ...
            quad(@(t)dkint(t,lp1,lT(v),plm.nY,plm.npcparm, ...
            lfac(1:plm.npcparm)),eps,plm.npcparm2);
    end
end

function q = dkint(t,lp1,lT,K,r,lfac)
lp2 = (K-r-1).*log(1-t);
ltr = r.*log(t);
L1  = real(lp1 + lp2 + ltr);
s1  = (lT > ltr).*exp(L1);
j   = (1:r)';
lp3 = lT + (j-1)*log(r*log(t)-lT) ...
    - repmat(lfac(j),[1 numel(t)]);
L2  = real(lp1 + repmat(lp2,[r 1]) + lp3);
s2  = (lT <= ltr).*sum(exp(L2));
q   = s1 + s2;

function A = awtk(lw,t,k,lfac)
ltk = k.*log(t);
tk = real(exp(ltk));
s = (1:k)';
L = bsxfun(@plus,lw,...
    bsxfun(@minus,(s-1)*log(k*log(t)-lw),lfac(s)));
S = sum(real(exp(L)),1);
A = (lw <= ltk).*S + (lw > ltk).*tk;

% ==============================================================
function T = taylortibshirani(G,df2,plm,c)
P = palm_gpvals(G,plm.rC(c),df2);
[~,tmp] = sort(P);
[~,prank] = sort(tmp);
T = sum(1-P.*(plm.nY+1)./prank)/plm.nY;

function P = taylortibshiranip(T,plm)
P = normcdf(-T,0,1/sqrt(plm.nY));

% ==============================================================
function T = jiang(G,df2,plm,c)
P = palm_gpval(G,plm.rC(c),df2);
[~,tmp] = sort(P);
[~,prank] = sort(tmp);
T = sum((P<=plm.npcparm).*(1-P.*(plm.nY+1)./prank))/plm.nY;

% ==============================================================
% Below are other useful functions:
% ==============================================================
function padj = fastfdr(pval)
% Compute FDR-adjusted p-values

V = numel(pval);
[pval,oidx] = sort(pval);
[~,oidxR]   = sort(oidx);
padj = zeros(size(pval));
prev = 1;
for i = V:-1:1,
    padj(i) = min(prev,pval(i)*V/i);
    prev = padj(i);
end
padj = padj(oidxR);

% ==============================================================
function savedof(df1,df2,fname)
% Save the degrees of freedom.
% This is faster than dlmwrite.

fdof = fopen(fname,'w');
fprintf(fdof,'%g\n',df1);
fprintf(fdof,'%g,',df2);
fseek(fdof,-1,'cof');
fprintf(fdof,'\n');
fclose(fdof);

% ==============================================================
function S = spr(X)
% Compute the matrix with the sum of products.
% X is a 3D array, with the resilduals of the GLM.
% - 1st dimension are the subjects
% - 2nd dimension would tipically be voxels
% - 3rd dimension the modalities.
% 
% S is the sum of products that make up the covariance
% matrix:
% - 1st and 3rd dimension have the same size as the number of
%   modalities and the 2nd dimension are typically the voxels.

% Swap dimensions of voxels by modalities
X = permute(X,[1 3 2]);

% To make it faster, the check should be made just once, and
% the result kept throughout runs.
persistent useway1;
if isempty(useway1),
    
    % Test both ways and compute the timings.
    tic; S1 = way1(X); w1 = toc;
    tic; S2 = way2(X); w2 = toc;

    % The variables sp1 and sp2 should be absolutely
    % identical but they may have sightly different numerical
    % precisions so to be consistent, choose the same that will
    % be used for all permutations later
    if w1 < w2,
        useway1 = true;
        S = S1;
    else
        useway1 = false;
        S = S2;
    end
else
    if useway1,
        S = way1(X);
    else
        S = way2(X);
    end
end

function sp = way1(X)
% This is still part of the spr function.
% Way 1: this tends to be faster for Octave and if
% the number of levels in X is smaller than about 5.
[~,nY,nT] = size(X);
sp = zeros(nY,nY,nT);
for y1 = 1:nY,
    for y2 = 1:y1,
        sp(y1,y2,:) = sum(X(:,y1,:).*X(:,y2,:),1);
        if y1 ~= y2,
            sp(y2,y1,:) = sp(y1,y2,:);
        end
    end
end

function sp = way2(X)
% This is still part of the spr function.
% Way 2: This tends to be faster in Matlab or if
% there are many levels in X, e.g., more than about 7.
[~,nY,nT] = size(X);
sp = zeros(nY,nY,nT);
for t = 1:nT,
    sp(:,:,t) = (X(:,:,t)'*X(:,:,t));
end

% ==============================================================
function C = pascaltri(K)
% Returns the coefficients for a binomial expansion of
% power K, except the last term. This is used by the Tippett
% method to avoid issues with numerical precision.

persistent Cp;
if isempty(Cp),
    K = K + 1;
    if K <= 2,
        Cp = horzcat(ones(1,K),0);
    elseif K >= 3,
        Rprev = [1 1 0];
        for r = 3:K,
            Cp = horzcat(Rprev + fliplr(Rprev),0);
            Rprev = Cp;
        end
    end
end
C = Cp(1:end-2);

% Finished! :-)