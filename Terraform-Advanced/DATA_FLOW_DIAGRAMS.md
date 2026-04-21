# Terraform-Advanced - Data Flow & Architecture Diagrams

## 🔄 **Data Flow Diagrams**

### **1. Pod Creation Flow**

```
User Input
│
└─ kubectl create deployment nginx --image=nginx:latest
   │
   ├─ Request → AWS ELB (Load Balancer)
   │           [Distributes HTTPS traffic]
   │
   └─ Request → EKS API Server (port 443)
      │
      ├─ Step 1: Authentication
      │  └─ User identity verified via OIDC/X.509 cert
      │
      ├─ Step 2: Authorization (RBAC)
      │  └─ Check: Can this user create deployments? YES
      │
      ├─ Step 3: Validation
      │  └─ Verify image name, resource limits, etc.
      │
      └─ Step 4: Persist to etcd
         └─ Deployment object → KMS encrypted → etcd database
            │
            ├─ EKS Cluster (Control Plane)
            │ ├─ API Server (received request)
            │ ├─ etcd (stores deployment)
            │ ├─ Scheduler (will place pods)
            │ ├─ Controller Manager (creates replicaset)
            │ └─ CloudWatch (logs request to /aws/eks/kkp-cluster/cluster)
            │
            └─ Deployment Controller
               │
               ├─ Watches for new Deployments
               ├─ Creates ReplicaSet (manages pod replicas)
               │
               └─ ReplicaSet Controller
                  │
                  ├─ Watches for new ReplicaSets
                  ├─ Creates 3 Pod objects
                  │
                  └─ Scheduler
                     │
                     ├─ Receives 3 Pod objects
                     │
                     ├─ Step 1: Filtering
                     │  ├─ Node 1 (t3.medium): Can fit? 
                     │  │  CPU needed: 100m, Available: 1000m = YES
                     │  └─ Node 2 (t3.medium): Can fit? YES
                     │
                     ├─ Step 2: Scoring
                     │  ├─ Node 1 score: 50 (less CPU available)
                     │  └─ Node 2 score: 80 (more CPU available)
                     │
                     ├─ Step 3: Binding
                     │  ├─ Pod 1 → Node 2 (higher score)
                     │  ├─ Pod 2 → Node 1
                     │  └─ Pod 3 → Node 2
                     │
                     └─ API Server updates Pod.spec.nodeName
                        │
                        ├─ Pod 1 → stored in etcd (encrypted)
                        ├─ Pod 2 → stored in etcd (encrypted)
                        └─ Pod 3 → stored in etcd (encrypted)
                           │
                           └─ kubelet on Node 1 & Node 2 watch for assignments
                              │
                              ├─ kubelet discovers its pods
                              │
                              ├─ Step 1: Pull Image
                              │  └─ docker pull nginx:latest
                              │     └─ Queries ECR (uses Node IAM role)
                              │
                              ├─ Step 2: Create Container
                              │  └─ docker run -e ... nginx:latest
                              │
                              ├─ Step 3: Configure Networking
                              │  └─ VPC CNI Plugin assigns IP from VPC CIDR
                              │     ├─ Pod gets: 10.0.0.50 (from subnet range)
                              │     └─ Stored in etcd
                              │
                              ├─ Step 4: Mount Volumes (if any)
                              │  └─ If PVC requested:
                              │     ├─ EBS CSI Driver detects PVC
                              │     ├─ Calls AWS API: CreateVolume
                              │     └─ AWS API call uses:
                              │        ├─ IRSA role (ebs-csi-driver)
                              │        ├─ OIDC token signed by Kubernetes
                              │        ├─ AWS STS verifies OIDC signature
                              │        └─ Temporary credentials issued
                              │
                              └─ Status: Running
                                 ├─ Pod ready to receive traffic
                                 ├─ Status → etcd
                                 └─ API Server reports to user: RUNNING
```

---

### **2. Pod-to-Pod Communication Flow**

```
Pod A (nginx)                     Pod B (app)
10.0.0.50                         10.0.1.25
(Node 1, AZ-1a)                   (Node 2, AZ-1b)
│                                 │
├─ Application wants to call nginx ←─ curl http://nginx:8080
│  └─ Query DNS: nginx.default.svc.cluster.local
│     │
│     └─ CoreDNS (runs on both nodes as DaemonSet)
│        ├─ Looks up: nginx.default
│        ├─ Queries etcd for Service object
│        ├─ Returns ClusterIP: 172.20.100.10
│        │
│        └─ kubelet caches result
│
├─ Pod B creates request packet
│  └─ Destination IP: 172.20.100.10
│     (Service IP, not a real IP)
│
└─ Packet reaches Node 2's network stack
   │
   ├─ kube-proxy (runs on Node 2)
   │  │
   │  ├─ Watches for Services and Endpoints
   │  ├─ Creates iptables rules:
   │  │  │
   │  │  ├─ IF destination == 172.20.100.10:8080
   │  │  │  └─ THEN randomly select one of the backend pods
   │  │  │     ├─ 10.0.0.50:8080 (35% probability)
   │  │  │     ├─ 10.0.0.51:8080 (33% probability)
   │  │  │     └─ 10.0.0.52:8080 (32% probability)
   │  │  │
   │  │  └─ Rewrite destination: 172.20.100.10 → 10.0.0.50
   │  │
   │  └─ Iptables rules applied by kernel
   │
   └─ Packet modified:
      └─ New destination: 10.0.0.50:8080 (actual pod)
         │
         └─ VPC routing (direct VPC networking)
            ├─ Packet travels on AWS VPC network
            ├─ No need for overlay network
            ├─ Direct EC2→EC2 communication
            │
            └─ Node 1 receives packet
               │
               └─ kubernetes.io/cni/networks annotation
                  ├─ Routes to container network interface
                  │
                  └─ Pod A receives request
                     │
                     ├─ nginx processes request
                     ├─ Responds with HTTP 200
                     │
                     └─ Response packet (reverse path)
                        ├─ Source: 10.0.0.50:8080
                        ├─ Destination: 10.0.1.25:xxxxx
                        │
                        └─ iptables rewrites:
                           └─ Source → 172.20.100.10:8080 (Service IP)
                              │
                              └─ Pod B receives response (from Service IP perspective)
```

---

### **3. EBS Persistent Volume Flow**

```
User creates PersistentVolumeClaim (PVC)
│
├─ kubectl create -f pvc.yaml
│  │
│  ├─ Object → API Server
│  ├─ Stored in etcd (encrypted with KMS)
│  │
│  └─ Storage provisioner detects PVC
│     └─ EBS CSI Driver (runs as StatefulSet)
│        │
│        ├─ Controller Pod watches for PVCs
│        │
│        ├─ Pod has ServiceAccount: ebs-csi-controller-sa
│        │  │
│        │  ├─ Kubernetes provides JWT token
│        │  │  └─ Token signed by Kubernetes: 
│        │  │     eyJhbGciOiJSUzI1NiIsImtpZCI6IkFCQzEyMyJ9...
│        │  │
│        │  ├─ Pod queries AWS STS:
│        │  │  └─ POST https://sts.amazonaws.com/
│        │  │     ├─ Action=AssumeRoleWithWebIdentity
│        │  │     ├─ RoleArn=arn:aws:iam::ACCOUNT:role/ebs-csi-driver
│        │  │     └─ WebIdentityToken=<JWT from step above>
│        │  │
│        │  └─ AWS STS verifies:
│        │     ├─ Check OIDC provider: oidc.eks.us-east-1.amazonaws.com
│        │     ├─ Verify certificate (thumbprint: 9e99...)
│        │     ├─ Verify token signature using Kubernetes public key
│        │     ├─ Extract claim: sub = system:serviceaccount:kube-system:ebs-csi-controller-sa
│        │     │
│        │     └─ If all valid, issue temporary credentials:
│        │        ├─ AccessKeyId: ASIA...
│        │        ├─ SecretAccessKey: ...
│        │        ├─ SessionToken: ...
│        │        └─ Expiration: 1 hour
│        │
│        ├─ Pod stores credentials (environment variables)
│        │
│        ├─ Pod calls AWS API: CreateVolume
│        │  │
│        │  ├─ AWS SDK uses temporary credentials
│        │  │
│        │  ├─ API Call:
│        │  │  ec2.create_volume(
│        │  │    AvailabilityZone='us-east-1a',
│        │  │    Size=10,  # GB
│        │  │    Encrypted=True,
│        │  │    KmsKeyId='arn:aws:kms:us-east-1:ACCOUNT:key/...'
│        │  │  )
│        │  │
│        │  └─ AWS creates EBS volume
│        │     ├─ Volume ID: vol-0123456789abcdef0
│        │     └─ Encrypted with KMS key (not readable without key)
│        │
│        ├─ Pod calls AWS API: CreateSnapshot (optional)
│        │
│        └─ Controller creates PersistentVolume (PV) object
│           │
│           ├─ Stored in etcd:
│           │  {
│           │    "metadata": {"name": "pvc-abc123"},
│           │    "spec": {
│           │      "capacity": {"storage": "10Gi"},
│           │      "awsElasticBlockStore": {
│           │        "volumeID": "vol-0123456789abcdef0"
│           │      }
│           │    }
│           │  }
│           │
│           └─ Scheduler attaches volume to appropriate node
│              │
│              ├─ Scheduler sees: Pod needs PVC
│              │
│              ├─ Query etcd: Where is PV vol-0123... located?
│              │  └─ AZ: us-east-1a (because EBS volume in AZ-1a)
│              │
│              ├─ Filter nodes: Which are in us-east-1a?
│              │  └─ Node 1 is in us-east-1a (available for pod)
│              │
│              ├─ Place pod on Node 1
│              │
│              └─ kubelet on Node 1:
│                 │
│                 ├─ Detects pod with PVC volume
│                 │
│                 ├─ Call AWS API: AttachVolume
│                 │  │
│                 │  ├─ Uses Node IAM role (assumed by EC2 instance)
│                 │  │  └─ Already has credentials (no OIDC needed)
│                 │  │
│                 │  ├─ AWS attaches volume to EC2 instance
│                 │  │  └─ Device: /dev/xvda
│                 │  │
│                 │  └─ kubelet waits for device to appear
│                 │
│                 ├─ Format volume (if new):
│                 │  └─ mkfs.ext4 /dev/xvda
│                 │
│                 ├─ Mount volume to container:
│                 │  └─ mount /dev/xvda /mnt/data
│                 │
│                 └─ Container gets write access to /mnt/data
                    │
                    └─ Data persisted on EBS volume
                       ├─ Encrypted with KMS key
                       ├─ Replicated within AZ
                       └─ Can be backed up with snapshots
```

---

### **4. IRSA Authentication Flow**

```
EBS CSI Driver Pod Lifecycle
│
├─ Kubernetes creates pod in kube-system namespace
│  └─ Pod has serviceAccountName: ebs-csi-controller-sa
│
├─ Kubernetes mounts service account token
│  │
│  └─ Volume Mount: /var/run/secrets/kubernetes.io/serviceaccount/token
│     │
│     ├─ Token content: JWT
│     │  {
│     │    "iss": "https://oidc.eks.us-east-1.amazonaws.com/id/ABC123DEF456",
│     │    "sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
│     │    "aud": ["sts.amazonaws.com"],
│     │    "exp": 1714000000,
│     │    "iat": 1713986000
│     │  }
│     │
│     └─ Token signed with Kubernetes private key
│
├─ Application in pod reads token from file
│  └─ read("/var/run/secrets/kubernetes.io/serviceaccount/token")
│
├─ Pod calls AWS STS with token
│  │
│  ├─ POST https://sts.amazonaws.com/?Action=AssumeRoleWithWebIdentity
│  │
│  ├─ Parameters:
│  │  ├─ RoleArn=arn:aws:iam::ACCOUNT:role/ebs-csi-driver
│  │  ├─ RoleSessionName=ebs-csi-controller-sa
│  │  └─ WebIdentityToken=eyJhbGciOiJSUzI1NiJ9...
│  │
│  └─ STS receives request
│
├─ AWS STS verification steps
│  │
│  ├─ Step 1: Parse JWT
│  │  └─ Extract issuer: https://oidc.eks.us-east-1.amazonaws.com/id/ABC123DEF456
│  │
│  ├─ Step 2: Look up OIDC provider configuration
│  │  └─ Query: AWS OIDC providers list
│  │     ├─ Found: arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.us-east-1.amazonaws.com
│  │     ├─ Issuer matches: ✓
│  │     └─ Thumbprint matches: ✓ (9e99a48a9960b14926bb7f3b02e22da2b0ab7280)
│  │
│  ├─ Step 3: Verify JWT signature
│  │  │
│  │  ├─ Fetch Kubernetes public key from OIDC issuer
│  │  │  └─ GET https://oidc.eks.us-east-1.amazonaws.com/id/ABC123DEF456/.well-known/openid-configuration
│  │  │     └─ Returns: jwks_uri
│  │  │
│  │  ├─ Fetch JWKS (JSON Web Key Set)
│  │  │  └─ GET https://oidc.eks.us-east-1.amazonaws.com/id/ABC123DEF456/keys
│  │  │     └─ Returns: { "keys": [{"kid": "...", "kty": "RSA", "n": "...", "e": "..."}]}
│  │  │
│  │  └─ Verify JWT signature using public key
│  │     ├─ Header: eyJhbGciOiJSUzI1NiIsImtpZCI6IkFCQzEyMyJ9 (decoded)
│  │     ├─ Payload: eyJpc3MiOiJodHRwcyI6IC4uLn0 (what we care about)
│  │     └─ Signature: verified ✓
│  │
│  ├─ Step 4: Verify claims in token
│  │  ├─ Check: issuer == OIDC provider endpoint ✓
│  │  ├─ Check: audience == sts.amazonaws.com ✓
│  │  ├─ Check: subject == system:serviceaccount:kube-system:ebs-csi-controller-sa ✓
│  │  └─ Check: expiration > current_time ✓
│  │
│  ├─ Step 5: Look up IAM role
│  │  │
│  │  ├─ Get role: arn:aws:iam::ACCOUNT:role/ebs-csi-driver
│  │  │
│  │  └─ Check trust relationship:
│  │     {
│  │       "Statement": [{
│  │         "Effect": "Allow",
│  │         "Principal": {
│  │           "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.us-east-1.amazonaws.com"
│  │         },
│  │         "Action": "sts:AssumeRoleWithWebIdentity",
│  │         "Condition": {
│  │           "StringEquals": {
│  │             "oidc.eks.us-east-1.amazonaws.com:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
│  │           }
│  │         }
│  │       }]
│  │     }
│  │     └─ Condition matches: ✓
│  │
│  └─ Step 6: All checks passed!
│     └─ Issue temporary credentials
│
├─ STS response to pod
│  │
│  ├─ AssumeRoleResponse:
│  │  ├─ AccessKeyId: ASIAJQ7...
│  │  ├─ SecretAccessKey: 7q8e+O9...
│  │  ├─ SessionToken: AQoDYXdzE...
│  │  └─ Expiration: 2026-04-21T11:30:00Z (1 hour from now)
│  │
│  └─ Pod stores credentials in memory
│     └─ (or environment variables, or ~/.aws/credentials)
│
└─ Pod now calls AWS APIs with temporary credentials
   │
   ├─ aws ec2 create-volume
   │  └─ Uses: AccessKeyId + SecretAccessKey + SessionToken
   │
   ├─ AWS validates:
   │  ├─ Check: credentials are valid ✓
   │  ├─ Check: credentials haven't expired ✓
   │  ├─ Check: assume-role session is active ✓
   │  └─ Check: role has CreateVolume permission ✓
   │
   └─ API request processed successfully
      └─ EBS volume created
```

---

### **5. Security Group & Network Flow**

```
User outside VPC (1.2.3.4)
│
├─ Tries to access EKS API (https://xxx.eks.us-east-1.amazonaws.com)
│  │
│  ├─ Request hits AWS load balancer
│  │  └─ LB forwards to EKS cluster endpoint
│  │
│  └─ Security Group: kkp_cluster_sg checks:
│     │
│     ├─ SOURCE: 1.2.3.4
│     ├─ PROTOCOL: TCP
│     ├─ PORT: 443
│     │
│     └─ Rule check (INGRESS):
│        ├─ Rule 1: Port 443 from kkp_node_sg? 
│        │  └─ NO (source is not from node SG)
│        │
│        └─ No rule matches
│           └─ RESULT: DENIED ✗ (Connection refused)
│
│
├─ Pod on Worker Node tries to access EKS API (internal)
│  │
│  ├─ Source: 10.0.0.50 (pod IP)
│  ├─ Destination: 172.20.100.1 (kubernetes.default.svc.cluster.local)
│  │              (This is the service endpoint, actually the API server)
│  │
│  └─ Security Group: kkp_cluster_sg checks:
│     │
│     ├─ SOURCE: 10.0.0.50 (originates from Node 1)
│     │  └─ Actually from: kkp_node_sg (security group of node)
│     │
│     ├─ PROTOCOL: TCP
│     ├─ PORT: 443
│     │
│     └─ Rule check (INGRESS):
│        ├─ Rule: Port 443 from kkp_node_sg? 
│        │  └─ YES ✓
│        │
│        └─ RESULT: ALLOWED ✓ (Connection established)
│
│
└─ Communication between nodes in cluster
   │
   ├─ Node 1 to Node 2
   │  │
   │  ├─ Source: 10.0.0.10 (Node 1)
   │  ├─ Destination: 10.0.1.10 (Node 2)
   │  │
   │  └─ Security Group: kkp_node_sg checks:
   │     │
   │     ├─ Rule: All traffic from VPC (10.0.0.0/16)?
   │     │  └─ YES ✓ (Both nodes in VPC CIDR)
   │     │
   │     └─ RESULT: ALLOWED ✓ (Kubelet to kubelet communication)
```

---

## 📊 **Component Interaction Matrix**

```
                Cluster  Node    etcd   CNI    CoreDNS  kubelet
                  SG     SG             Plugin
─────────────────────────────────────────────────────────────────
Cluster SG         -      ←443   ✓      ✓      ✓       ✓
Node SG           ✓←      -      ✓      ✓      ✓       ✓
etcd              ✓←     ✓←      -      -      -       ✓←
CNI Plugin        -      ✓←      -      -      -       ✓
CoreDNS           -      ✓←      ✓      -      -       -
kubelet           →443   -      →6443  ✓      →53     -

Legend:
→ = Initiates connection
← = Receives connection
✓ = Can communicate
- = No direct communication
```

---

## 🔐 **Encryption & Key Management Flow**

```
Sensitive Data Storage Paths
│
├─ Kubernetes Secret (in memory or etcd)
│  │
│  ├─ Step 1: User creates secret
│  │  └─ kubectl create secret generic db-password --from-literal=password=supersecret
│  │
│  ├─ Step 2: API Server validates
│  │  └─ Checks user has permission
│  │
│  ├─ Step 3: BEFORE storing in etcd
│  │  │
│  │  ├─ Prepare: {"data": {"password": "c3VwZXJzZWNyZXQ="}}
│  │  │              (base64 encoded, NOT encrypted yet)
│  │  │
│  │  └─ Encrypt with KMS key (eks KMS key)
│  │     │
│  │     ├─ API Server → KMS: "Encrypt this data with key arn:aws:kms:..."
│  │     │
│  │     └─ KMS returns: <binary encrypted blob>
│  │
│  ├─ Step 4: Store in etcd
│  │  └─ etcd stores: <encrypted blob>
│  │     (Actual data is unreadable without KMS key)
│  │
│  └─ Step 5: Retrieve secret
│     │
│     ├─ API Server reads from etcd: <encrypted blob>
│     │
│     ├─ API Server → KMS: "Decrypt this blob"
│     │
│     ├─ KMS verifies:
│     │  ├─ Is this key active? YES
│     │  ├─ Do credentials have permission? YES (assume-role via IAM)
│     │  └─ Is key in allowed regions? YES
│     │
│     └─ KMS returns: plaintext data
│        └─ API Server responds to kubelet with decrypted secret
│
│
├─ EBS Volume (persistent data)
│  │
│  ├─ Step 1: EBS CSI creates volume
│  │  └─ CreateVolume(Encrypted=True, KmsKeyId=arn:aws:kms:...)
│  │
│  ├─ Step 2: EBS encrypts at rest
│  │  └─ AWS hardware encrypts each sector using KMS key
│  │
│  ├─ Step 3: VM instances can read/write
│  │  ├─ Attach volume to EC2 instance
│  │  ├─ EC2 has IAM role with decrypt permission
│  │  └─ EBS automatically encrypts/decrypts on each I/O
│  │
│  └─ Step 4: Data in motion (EBS snapshot)
│     │
│     ├─ Create snapshot → Stored in S3
│     │
│     └─ Snapshot is encrypted with same KMS key
│        (Automatic, no additional configuration needed)
│
│
└─ Transit Encryption (TLS)
   │
   ├─ API Server → etcd communication
   │  └─ TLS encrypted (certificate-based, not KMS)
   │
   ├─ kubelet → API Server
   │  └─ TLS encrypted (client cert auth)
   │
   └─ Pod → Service communication
      └─ NOT encrypted by default (same VPC, trusted network)
         (Application-level encryption recommended: mTLS, service mesh)
```

---

## 🎯 **Request Path Examples**

### **Example 1: kubectl apply -f deployment.yaml**

```
1. kubectl reads file
   └─ deployment.yaml

2. kubectl → API Server (HTTPS)
   ├─ Endpoint: https://xxx.eks.us-east-1.amazonaws.com
   ├─ Authentication: Certificate or OIDC token
   └─ Payload: Deployment object

3. EKS API Server processes
   ├─ TLS handshake
   ├─ Verify client certificate/token
   ├─ RBAC check: Can user create deployments? YES
   └─ Webhook validation (if configured)

4. API Server → etcd
   ├─ Encrypt with KMS
   └─ Store: /apis/apps/v1/namespaces/default/deployments/my-app

5. Controllers watch for changes
   ├─ Deployment Controller → Create ReplicaSet
   ├─ ReplicaSet Controller → Create 3 Pods
   └─ Scheduler → Assign pods to nodes

6. kubelet on nodes watch for assignments
   ├─ Kubelet-1: I got 2 pods
   ├─ Kubelet-2: I got 1 pod
   └─ Pull images, create containers, report status

7. Status → etcd
   └─ CloudWatch logs all changes

8. kubectl get deployment
   ├─ kubectl → API Server (HTTPS)
   ├─ API Server reads from etcd
   └─ kubectl displays: 3/3 Running
```

---

**This completes the comprehensive architecture documentation!**

Each diagram shows exactly how data flows through the system, how security is maintained, and where encryption happens. Reference these diagrams when troubleshooting or designing similar systems.
