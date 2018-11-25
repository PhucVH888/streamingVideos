include "globals.mzn";

% Hint 1: why and how to use data center as a bin?
%      - in case the connected cache is full, there is still room to store the video for the endpoint's request.

% Hint 2: in which case the videos will be clone? what for?
%      - in case the cache has cheaper latency, cloning the videos for requests of the same videos from several endpoints works optimal.

% Question: how to specify the fixed given set of load or number of used caches?
%     - In test me_at_the_zoo: 
%          + given used caches  = 32.
%          + used caches (load) = 47.
%          + the result will be "UNSATISFIABLE" if change the set of load to CACHE ( = 1..C )

% Hint 3: addressed in the new model.

% Hint 4: precompute in python 
%    - to sum up the duplicated requested video => marked as (0,0,0).
%    - to mark the videos whose sizes exceed the capacity of the cache servers => marked as 0.


%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%
int: V;% (1 .. 10.000) the number of videos
int: E;% (1 .. 1.000) the number of endpoints
int: R;% (1 .. 1.000.000) the number of request descriptions

int: C;% (1 .. 1.000) the number of cache servers
int: X;% (1 .. 500.000) the capacity of each cache server in MB

set of int: VID      = 1..V;
set of int: ENDPOINT = 1..E;
set of int: REQUEST  = 1..R;

set of int: CACHE    = 1..C;
set of int: CACHE0   = 0..C; % 0 : data center

set of int: CAP      = 1..X;
set of int: CAP0     = 0..X;

set of int: SIZE     = 1..1000;
set of int: SIZE0    = 0..1000;

% sum of all connected caches K
int: total_connection; 

% video sizes
array[VID] of SIZE: videoSize;

% capacity of data center
int: dcCap = sum(videoSize)*20;
set of int: DCAP = 0..dcCap;

% Ld: data center latency       ( 2 .. 4.000 )
% K: number of connected caches ( 0 .. C )
enum LDK = {Ld, K};
array[ENDPOINT, LDK] of 0..4000: endpoint;

% Rv: requested video      ( 0 .. V )
% Re: coming from endpoint ( 0 .. E )
% Rn: number of requests   ( 0 .. 10.000)
enum RVEN = {Rv, Re, Rn};
array[REQS, RVEN] of 0..10000: request;
int: realReq; % number of distinct request

% set of int: RREQ = 0..realReq;
int: reqs = realReq + nUnReqVid;
set of int: REQS = 1..reqs;
set of int: RREQ = 1..realReq;
set of int: UNREQ = realReq+1 .. reqs;

% ei: from endpoint 
% ci: to cache ( 0 .. C ), 
% Lc: latency  ( 1 .. 500 < Ld ) in milliseconds
% eConCache[en, ca] : 
%    Lc: connects to cache id; 
%    0 : not connect
array[ENDPOINT, CACHE] of 0..1000: eConCache;
array[ENDPOINT] of int: ecc = [ sum(ca in CACHE)(eConCache[en,ca]) | en in ENDPOINT ];

% total number of requests
int: nReq = sum(re in REQUEST)(request[ re, Rn ]);

array[VID] of SIZE0: videoInCap; % = [50, 50, 80, 30, 0];
array[REQS] of SIZE0: weight = [ videoSize[request[req, Rv]] | req in REQS ];

% valid requested videos
int: nReqVid;
array[VID] of SIZE0: reqVid;

% unrequested and oversize videos
int: nUnReqVid;
array[VID] of DCAP: unreqVid;

%%%%%%%%%%%%%%%%%%%%%%%%%
% VARIABLES
%%%%%%%%%%%%%%%%%%%%%%%%%
% array[VID] of var SIZE: bin;
% array[VID] of var CAP0: load;
var int: savingTime;

array[REQS] of var DCAP: bin;
array[REQS] of var DCAP: load;


%%%%%%%%%%%%%%%%%%%%%%%%%
% CONSTRAINTS
%%%%%%%%%%%%%%%%%%%%%%%%%
% all bin caps in SIZE, except bin[0] - data center
% constraint forall(req in RREQ)(load[req] in CAP); % bin[req] in CACHE /\ 

% put unrequested and oversize videos to bin[0] = data center
% constraint forall(req in UNREQ)(bin[req] = 0);
constraint forall(req in RREQ)(bin[req] != 0);

% % bin contains requested videos only
% constraint exists(req in REQUEST where request[req, Rn] > 0)(
%   eConCache[ request[req, Re], bin[ request[req, Rv] ]] > 0
% );

constraint bin_packing_load(load, bin, weight);

%%%%%%%%%%%%%%%%%%%%%%%%%
% Objective Function
%%%%%%%%%%%%%%%%%%%%%%%%%
% savingTime = sum(req in REQUEST where request[req, Rn] > 0)(
%   let { int: rv = request[req, Rv]; % requested video
%         int: re = request[req, Re]; % requested endpoint
%         int: rn = request[req, Rn]; % number of requests
%         int: ld = endpoint[re, Ld]; % latency of data center to endpoint
%         var int: lc = eConCache[re, bin[request[req, Rv]]];% latency of cache to endpoint
%    } in (
%       (ld - lc) % saving time when storing in cache
%       *            
%       (bool2int(videoInCap[rv] > 0)) % size=0: stored in data center, saving 0 ms
%       *  
%       rn % number of requests for video rv
% ));

solve :: int_search(
        bin ++
        load
        , 
        first_fail, indomain_min, complete) maximize savingTime;

%%%%%%%%%%%%%%%%%%%%%%%%%
% Output
%%%%%%%%%%%%%%%%%%%%%%%%%
output ["bin      = " ++ show(bin) ++ "\n" ++
        "load     = " ++ show(load) ++ "\n" ++
        "video    = " ++ show(weight) ++ "\n" ++
        "score    = " ++ show((savingTime/nReq)*1000) ++ "\n" ++
        "used caches            = " ++ show(usedCache) ++ "\n" ++
        "given connected caches = " ++ show(total_connection) ++ "\n" ++
        "ecc = " ++ show(ecc) ++ "\n" ++
%         "total video sizes      = " ++ show(totalVideoSize) ++ "\n" ++
        ""];

var int: usedCache = sum(vi in VID)(bool2int(load[vi] > 0));

      