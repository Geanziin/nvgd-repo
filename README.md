# nvgd Arch Linux / CachyOS repository

Pacotes do [nvgd](https://github.com/Geanziin/nvgd) e do
[nvgd-dkms](https://github.com/Geanziin/nvgd-dkms).
OpenGL usa nvc0/NAK; Vulkan usa **NVK/NAK nativo**, sem Zink ou ANGLE.
Os ICDs Vulkan mantêm o nome upstream `nouveau_icd`.

## Configuração

Coloque este bloco **antes dos outros repositórios** em `/etc/pacman.conf`:

```ini
[nvgd]
SigLevel = Optional TrustAll
Server = https://github.com/Geanziin/nvgd-repo/releases/download/packages
```

Remova blocos antigos `[nouveau-lab]` e `[nvgd-dkms]`. Para migrar automaticamente:

Usuários do servidor GitHub Pages anterior também devem executar o instalador
abaixo para migrar a URL. Os novos binários ficam no release `packages`;
o histórico Git existente foi preservado.

```bash
curl -fLO https://raw.githubusercontent.com/Geanziin/nvgd-repo/main/install.sh
# Revise o script antes de executá-lo.
sudo bash install.sh
```

Os pacotes não são assinados; `Optional TrustAll` reduz a verificação de confiança.
Use somente se confiar neste repositório. Para atualizar, use `sudo pacman -Syu`,
não uma atualização parcial com `pacman -Sy` seguida de instalação isolada.

## Pacotes

| Pacote | Conteúdo |
| --- | --- |
| `nvgd-dkms` | Módulo de kernel nvgd com GSP e telemetria |
| `mesa-git` | Mesa 64-bit, OpenGL nativo, NVK, VA-API e vídeo |
| `lib32-mesa-git` | Mesa 32-bit, OpenGL nativo e NVK para Steam/Proton |
| `gpu-screen-recorder-git` | Captura e gravação |
| `gpu-screen-recorder-ui-git` | Interface gráfica |
| `gpu-screen-recorder-notification-git` | Notificações de gravação e replay |

Mesa 32/64-bit: `1:27.0.0_devel.r231969.g3e604079149-9`.
DKMS: `1.0.0-23`. O build 32-bit otimiza C/C++ e Rust em nível 3,
incluindo NVK, NIR e NAK. Isso corrige overhead de CPU do build anterior;
não representa garantia de FPS para um jogo específico.

### Validação AD104 em 2026-11-27

Na RTX 4060 Ti `10de:2788`, o Mesa -9 corrige clear de superfícies e a
submissão com múltiplos contextos: 35/35 casos de imagem e 10/10 rodadas de cada
teste concorrente passaram. NVDEC H.264, HEVC, VP9 e AV1, incluindo 10-bit e
AV1 film grain, produziu quadros idênticos à referência nos casos testados.
NVENC H.264 Baseline/Main/High e HEVC Main/Main10 passaram em encode/decode
estrito. Outras Ada continuam sem validação em hardware nesta rodada.
O relatório e os reproducers estão no fork
[`docs/nvgd-ada-20261127.md`](https://github.com/Geanziin/nvgd/blob/main/docs/nvgd-ada-20261127.md).
O nvgd-dkms -23 mantém os nove blobs do unlock e disponibiliza contadores de
vídeo também nos backends RM r535/r570. Reinicie a sessão gráfica após atualizar
Mesa; o compositor aberto mantém a biblioteca anterior carregada.

**Resultados de Performance e Desbloqueio de Hardware (RTX 3050 6GB GA107)**:
- **Tensor Core Speed-Select (2× Throughput de FP32 Accumulate)**:
  - `FEAT_OVR_PLM`: `0xffffff8f` ➔ `0xffffffff` (PLM destravado no boot)
  - `FEAT_READOUT_1`: `0x00400080` ➔ `0x00000000` (todas as 9 unidades em taxa total sem stalls)
  - `FEAT_OVR_SM_SPEED_SELECT` (SS0): `0x50404070` ➔ `0x88888888`
  - `FEAT_OVR_SM_SPEED_SELECT_1` (SS1): `0x00000006` ➔ `0x00000008`
- **Vulkan Nativo (NVK/NAK)**: `vkmark` — corridas armazenadas (RTX 3050 GA107): 2026-10-22 mediana **14076**; 2026-10-23 mediana **~15510**. Essas corridas **antecedem o desbloqueio** (commit bedd688fd, 27/out) e não evidenciam efeito dele. O valor "18004" divulgado antes não aparece em nenhum log e foi removido.
- **OpenGL 4.6 Nativo (nvc0/NAK)**: sem resultado de `glmark2` armazenado no lab — o "9067" divulgado antes não tem log e foi removido.
- **Emulação Android (Redroid Container)**: sem log ou artefato no lab — o "240 FPS" divulgado antes foi removido.

**Novo: HEVC encode nativo no NVENC e AV1 Film Grain no NVDEC**:
- **NVENC HEVC**: encode nativo por hardware em 8-bit (Main) e 10-bit (Main 10 / P010) no chip GA107 (classe C7B7), com alocação e chaveamento ping-pong de buffers de predição ME temporais (`SHARED_MEPRED_0` e `SHARED_MEPRED_1`) nos P-frames, eliminando timeouts de firmware; emissão de VPS/SPS/PPS nos frames IDR; e conformance window cropping para resolução visível exata.
- **NVDEC AV1 Film Grain**: implementação de síntese de grão de filme (seção 7.18) no firmware NVDEC, com templates e tabelas de scaling gerados dinamicamente sem estouro de TLS em dlopen, e display surfaces vinculadas com `SET_DISPLAY_BUF_SIZE`. Validado byte a byte contra a `libdav1d` de referência em 8-bit e 10-bit com SHA-256 idêntico.
- **NVDEC Decode**: decode nativo por Gallium/DRM em H.264, AV1, HEVC e VP9, cobrindo todos os formatos suportados pelo GA107 sem envolver ponte Vulkan Video nem bibliotecas proprietárias.
- **Tensor Core Speed-Select Unlock (Ampere; Ada: só a RTX 4090 por padrão)**: desbloqueio nativo direto no kernel driver `nvgd` da limitação de fábrica de issue rate dos Tensor Cores em operações de acumulação FP32 (FP16/BF16/TF32 → FP32). Remove o throttle de 50% via SEC2 Falcon V67 booter, liberando taxa 2x de throughput de tensores nas GPUs suportadas (2× é inferência de registrador — sem benchmark HMMA/IMMA antes/depois pelo lab; ex: RTX 3050 6GB GA107 `10de:2584`, RTX 3060 12GB GA106 `10de:2504`, RTX 4090 AD102 `10de:2684` — implementada, **não validada** — e chips desktop GA102/GA104; demais Ada atrás de `nvgd.tensor_unlock_experimental=1`, sem validação em hardware pelo lab). Fallback suave quando os microcódigos em `/usr/lib/firmware/gpu-unlock/610.43.03/` não estiverem presentes. Controlado via parâmetros `nvgd.tensor_unlock=1` (ativo por padrão) e `nvgd.tensor_unlock_experimental=0`. Comportamento em boot/reload: (a) warm boot com estado persistido — detecta e pula; (b) warm boot com estado resetado — re-executa (seguro, WPR2 baixo após reset); (c) reload após o card ter sido inicializado por um driver sem desbloqueio — recusa com `-EBUSY` ("power off first"), sem unlock até um power-off completo; (d) reload após unlock — pula limpo. Suspend/resume: o estado pode se perder (não validado em Ada); o unlock NÃO é reaplicado no resume — é preciso um power cycle.

```bash
sudo pacman -Syu nvgd/mesa-git nvgd/lib32-mesa-git nvgd/nvgd-dkms
```

---

## 🟣 Suporte ao Gentoo Linux (Ebuild Overlay)

O repositório `nvgd-repo` também funciona diretamente como overlay Portage do Gentoo.

### 1. Configurar o overlay em `/etc/portage/repos.conf/nvgd.conf`

```ini
[nvgd]
location = /var/db/repos/nvgd
sync-type = git
sync-uri = https://github.com/Geanziin/nvgd-repo.git
auto-sync = yes
```

### 2. Sincronizar o overlay

```bash
emaint sync -r nvgd
# ou
emerge --sync nvgd
```

### 3. Pacotes disponíveis no Gentoo

| Pacote | Categoria | Descrição |
| --- | --- | --- |
| `mesa` / `mesa-nvgd` | `media-libs` | Mesa fork nvgd com NVDEC/NVENC nativos, NVK e NAK |
| `nvgd-dkms` | `x11-drivers` | Módulo de kernel Nouveau com GSP-RM 615 e P-State P0 |
| `gpu-screen-recorder` | `media-video` | Gravador de tela VA-API NVENC |
| `gpu-screen-recorder-ui` | `media-video` | Interface GTK3 para gravação |
| `gpu-screen-recorder-notification` | `media-video` | Notificações e OSD de replay |

### 4. Instalação no Gentoo

```bash
# Se necessário, aceite as keywords nos arquivos de configuração do portage:
echo "media-libs/mesa ~amd64" >> /etc/portage/package.accept_keywords/nvgd
echo "x11-drivers/nvgd-dkms ~amd64" >> /etc/portage/package.accept_keywords/nvgd

# Suporte a 32-bit (lib32 / multilib para Steam, Wine e Proton):
echo "media-libs/mesa abi_x86_32" >> /etc/portage/package.use/mesa

# Compilar e instalar:
emerge --ask media-libs/mesa::nvgd
emerge --ask x11-drivers/nvgd-dkms::nvgd
emerge --ask media-video/gpu-screen-recorder::nvgd
```

Reinicie após atualizar o módulo de kernel; para atualizar apenas Mesa,
reabra os aplicativos para carregar as bibliotecas novas.

## Correção para a atualização ao kernel 7.3

O pacote antigo limitava o DKMS e o initramfs ao kernel 7.2. Após atualizar,
o módulo não era reconstruído e a máquina podia iniciar com simpledrm, sem
aceleração. O pacote novo remove a restrição de versão menor (mínimo 7.2),
inclui nvgd no initramfs quando ele está instalado para aquele kernel e adapta
o driver à remoção de `DRIVER_GEM_GPUVA` no DRM 7.3, mantendo a flag no 7.2.
Compilação validada em `7.3.0-3-cachyos`, sem warnings ou erros do compilador.
O kernel LTS 6.18 continua fora do suporte deste pacote.

Mesa incorpora os fixes oficiais recentes de descritores NVK, intervalo de
sincronização de memória e CMP do NV30, além dos fixes de barreiras NAK já
incluídos. GSP 615, P-State, renderização nativa e os hotpaths de vídeo do lab
foram preservados. O cross-build i686 não depende mais de wrappers em `/tmp`.

Verificação após reiniciar no kernel compatível:

```bash
uname -r
dkms status nvgd
lspci -nnk -d 10de:
vulkaninfo --summary
nvgd-status
```

`lspci` deve mostrar `Kernel driver in use: nvgd`, e Vulkan deve enumerar a
GPU NVIDIA com NVK. Se houver apenas simpledrm/llvmpipe, envie o log do boot
(`journalctl -b -k`) antes de tentar trocar o Mesa ou desativar NAK/GSP.

## Atualização pelo mantenedor

`./update-repo.sh` seleciona por metadados/vercmp a versão mais recente dos seis
pacotes em `$LAB_DIR/packaging` ou `x86_64` e gera `nvgd.db.tar.gz`.
`./update-repo.sh --publish` envia primeiro os binários e depois os bancos ao
release, faz commit dos metadados/receitas e `pull --rebase`/push. Os arquivos
`.pkg.tar.zst` novos não entram no Git. O release é
[`packages`](https://github.com/Geanziin/nvgd-repo/releases/tag/packages).
As receitas locais estão em `packaging/`; ainda dependem da árvore de build do lab.

Teste de referência dos hotpaths (144 combinações NV12 e limites do bitstream):

```bash
python3 tests/video-hotpaths.py /caminho/para/mesa
NVGD_TEST_SANITIZE=1 python3 tests/video-hotpaths.py /caminho/para/mesa
bash tests/dkms-config.sh
```
