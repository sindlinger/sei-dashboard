# GPU_WaveViz_1.0.4.mq5

## Visão geral
- Evolução do `GPU_WaveViz` alinhada à arquitetura **GpuEngine Service v2**.
- Acrescenta buffer de preview, métricas auxiliares (countdown, power, velocity) e HUD opcional para destacar os ciclos mais relevantes.

## Organização interna
- Buffers principais: `g_wave`, `g_preview`, `g_noise`.
- Vetor bidimensional `g_cycles[11][]` (até 11 ciclos plotáveis) mais arrays de cálculo (`g_countdown`, `g_power`, `g_velocity`).
- `OnInit` configura os buffers e registra todos como séries.
- `ResetBuffers` limpa os arrays a cada chamada para evitar resíduos entre ticks.
- `OnCalculate`:
  - Valida `GPUShared::frame_length`, `frame_count` e `cycle_count`.
  - Limita o número de ciclos por `InpMaxCycles`.
  - Seleciona os ciclos com maior Phase Locking Value (`GPUShared::plv_cycles`) quando disponível, preenchendo o vetor `selected_indices`.
  - Copia wave, preview e ruído mais recentes (`offset = (frame_count-1) * frame_length`).
  - Opcionalmente preenche HUD (`InpShowHud`) com dados de `GPUShared::last_info`.

## Integração com o GpuEngine
- Usa `../../Include/GPU/GPU_Shared.mqh` para ler saídas produzidas pelo serviço/dll através do `GpuEngineClient`.
- Depende de produtor como `GPU_EngineHub` ou indicadores “solo” que escrevam tanto o preview quanto os vetores `plv_cycles`/`snr_cycles`.
- Leva em conta o modo “service backend” exposto nas novas versões do cliente.

## Requisitos e inputs
- `InpShowPreview`: controla exibição do buffer de preview (onda bruta antes da reconstrução final).
- `InpShowNoise`: habilita linha de ruído residual.
- `InpMaxCycles`: máximo de ciclos mostrados (<= número disponível).
- `InpShowHud`: liga/desliga HUD textual que consome `GPUShared::last_info`.
- Precisa de pipeline `Build.ps1` atualizado para garantir que `GPU_Shared.mqh` publique os vetores extras (preview, plv, snr, power, velocity).

## Uso recomendado
- Combine com `GPU_EngineHub` quando este estiver enviando jobs com flags `JOB_FLAG_STFT` + `JOB_FLAG_CYCLES`, garantindo `preview` e `cycles` populados.
- Utilize `InpShowHud=true` para depuração (latência, PLV, ELAPSED_MS) e desative em produção para reduzir ruído visual.
- Sincronize o arquivo para `runtime/Indicators/GPU/` via watchdog antes de instalar em terminais vinculados.
