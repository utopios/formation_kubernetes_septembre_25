
| Configuration | Privileged | Baseline | Restricted |
|--------------|------------|----------|------------|
| `privileged: true` | ✅ | ❌ | ❌ |
| `runAsUser: 0` | ✅ | ✅ | ❌ |
| `allowPrivilegeEscalation` | ✅ | ✅ | ❌ (false requis) |
| `readOnlyRootFilesystem` | ✅ | ✅ | ❌ (true requis) |
| `hostNetwork/hostPID` | ✅ | ❌ | ❌ |
| `hostPath: /etc` | ✅ | ❌ | ❌ |
| `hostPath: /tmp` | ✅ | ✅ | ❌ |
| Capabilities `SYS_ADMIN` | ✅ | ❌ | ❌ |
| Capabilities `NET_BIND_SERVICE` | ✅ | ✅ | ❌ (sauf ajout explicite) |
| seccomp undefined | ✅ | ✅ | ❌ |
