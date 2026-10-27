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
Server = https://geanziin.github.io/nvgd-repo/$arch
```

Remova blocos antigos `[nouveau-lab]` e `[nvgd-dkms]`. Para migrar automaticamente:

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

Mesa 32/64-bit: `1:27.0.0_devel.r231969.g3e604079149-1`.
DKMS: `1.0.0-20`. O build 32-bit otimiza C/C++ e Rust em nível 3,
incluindo NVK, NIR e NAK. Isso corrige overhead de CPU do build anterior;
não representa garantia de FPS para um jogo específico.

**Novo: HEVC encode nativo no NVENC e AV1 Film Grain no NVDEC**:
- **NVENC HEVC**: encode nativo por hardware em 8-bit (Main) e 10-bit (Main 10 / P010) no chip GA107 (classe C7B7), com alocação e chaveamento ping-pong de buffers de predição ME temporais (`SHARED_MEPRED_0` e `SHARED_MEPRED_1`) nos P-frames, eliminando timeouts de firmware; emissão de VPS/SPS/PPS nos frames IDR; e conformance window cropping para resolução visível exata.
- **NVDEC AV1 Film Grain**: implementação de síntese de grão de filme (seção 7.18) no firmware NVDEC, com templates e tabelas de scaling gerados dinamicamente sem estouro de TLS em dlopen, e display surfaces vinculadas com `SET_DISPLAY_BUF_SIZE`. Validado byte a byte contra a `libdav1d` de referência em 8-bit e 10-bit com SHA-256 idêntico.
- **NVDEC Decode**: decode nativo por Gallium/DRM em H.264, AV1, HEVC e VP9, cobrindo todos os formatos suportados pelo GA107 sem envolver ponte Vulkan Video nem bibliotecas proprietárias.
- **Tensor Core Speed-Select Unlock (Ampere & Ada)**: desbloqueio nativo direto no kernel driver `nvgd` da limitação de fábrica de issue rate dos Tensor Cores em operações de acumulação FP32 (FP16/BF16/TF32 → FP32). Remove o throttle de 50% via SEC2 Falcon V67 booter, liberando taxa 2x de throughput de tensores nas GPUs suportadas (ex: RTX 3050 6GB GA107 `10de:2584`, RTX 3060 12GB GA106 `10de:2504`, RTX 4090 AD102 `10de:2684` e chips desktop GA102/GA104). Idempotência instantânea integrada (ignora em warm boots/reloads) com fallback suave quando os microcódigos em `/usr/lib/firmware/gpu-unlock/610.43.03/` não estiverem presentes. Controlado via parâmetros `nvgd.tensor_unlock=1` (ativo por padrão) e `nvgd.tensor_unlock_experimental=0`.

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
`./update-repo.sh --publish` também faz commit/push e atualiza o release
[`packages`](https://github.com/Geanziin/nvgd-repo/releases/tag/packages).
As receitas locais estão em `packaging/`; ainda dependem da árvore de build do lab.

Teste de referência dos hotpaths (144 combinações NV12 e limites do bitstream):

```bash
python3 tests/video-hotpaths.py /caminho/para/mesa
NVGD_TEST_SANITIZE=1 python3 tests/video-hotpaths.py /caminho/para/mesa
bash tests/dkms-config.sh
```
