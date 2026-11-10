# M3 – Reduzindo o Toil

O custo do release manual, medido e classificado pelas 6 características do toil.

**O roteiro da aula (comandos, o que mostrar e o que falar) está no [README raiz](../README.md), seção "Passo 2".**

| Arquivo | Para que serve |
|---|---|
| `RELEASE_MANUAL.md` | o roteiro manual (sessão SSM, git pull, docker build, subir célula a célula) para executar e cronometrar |
| `toil-steps.csv` | os passos com tempos e características; edite com os tempos medidos |
| `toil_roi.py` | classifica os passos, calcula % de toil, horas/mês e o prazo de retorno da automação |
| `reset.sh` | restaura o CSV e o clone da EC2 alterado pelo release manual |
