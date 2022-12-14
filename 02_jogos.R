# Carregando pacotes --------------------------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(rvest)
library(quantmod)
library(httr)
library(tibble)
library(stringr)
library(reshape2)
library(readr)
library(purrr)

# Carregando dataframe de Jogadores ------------------------------------------------------------------------
dados_gerais <- read.csv2("csv/jogadores.csv")

# Criando variável páginas e criando variável 'p' que será a parte final do url (o número da página) -------
paginas <- ''
p <- 1

# Criando um laço for que armazenará o url de cada página dentro da variável paginas -----------------------
for (i in 1:33){
  paginas[p] <- paste('https://www.vlr.gg/matches/results/?page=', p, sep = '')
  p = p + 1
}

# Variável partidas e variável c ---------------------------------------------------------------------------
c <- 1
partidas <- 'a'

# Função que retorna o url de cada partida -----------------------------------------------------------------
funcaoPagina <- function(pagina){
  
  partidas <- read_html(pagina) %>% 
    html_nodes('a') %>% html_attr('href') # Nessa parte ele pega todos os urls que estão contidos na página.
  
  partidas <- partidas[15:64] # Aqui é separado os urls que são efetivamente de partidas.
  
  n <- 1
  
  for (i in partidas){
    partidas[n] <- paste('https://www.vlr.gg', partidas[n], sep = '') # Salvando urls dentro da variável partida
    n = n + 1
  }
  
  return(partidas)
  
}

# Criando f e uma lista que receberá todos os returns da funcaoPagina (url de cada partida) ----------------
f <- 1
a <- list()

# Executando um for que fará a iteração da funcaoPagina todas as vezes necessárias -------------------------
for (i in paginas){
  a[[length(a)+1]] = funcaoPagina(paginas[f])
  f = f + 1
}

# Fazendo unlist de 'a' e criando 'm' e 'dff' (lista que receberá todos os dados dos jogos) ----------------
m <- 1
a <- unlist(a)
dff <- list()

# Função que vai catalogar e retornar os dados das partidas -------------------------------------------------
catalogarporUrl <- function (string){
  tryCatch(
    
    {
      dados_gerais <- dplyr::select(dados_gerais, Player, R, ACS, K.D, KAST, ADR)
      row.names(dados_gerais) <- make.names(dados_gerais[,1], unique = T)
      dados_gerais <- dplyr::select(dados_gerais, -Player)
      dados_gerais$KAST <- parse_number(dados_gerais$KAST)
      
      info <- read_html(string) %>% 
        html_nodes("table") %>% 
        html_table()
      
      placar <- read_html(string) %>% 
        html_nodes("div.js-spoiler") %>% html_text(trim=T)
      
      placar <- str_replace_all(placar, '\t', '') %>% str_replace_all('\n', '')
      
      placar <- as.data.frame(placar[1])
      
      placar <- separate(placar, 'placar[1]', into = c('Time1', 'Time2'), sep = ':', extra = 'merge')
      
      ifelse(placar$Time1 > placar$Time2, ganhador <- 1, ganhador <- 0)
      
      timeA <- info[[1]]
      timeB <- info[[2]]
      
      timeA <- lapply(timeA, str_replace_all, '\n', '') %>% 
        lapply(str_replace_all, '\t', '')
      timeB <- lapply(timeB, str_replace_all, '\n', '') %>% 
        lapply(str_replace_all, '\t', '')
      
      timeA <- as.data.frame(timeA[1])
      timeB <- as.data.frame(timeB[1])
      
      colnames(timeA) <- '1'
      colnames(timeB) <- '1'
      
      timeA <- separate(timeA, '1', into = c("Player", "Team"), sep = "\\s+", extra = "merge")
      timeB <- separate(timeB, '1', into = c("Player", "Team"), sep ="\\s+", extra = "merge")
      
      timeA <- timeA$Player
      timeB <- timeB$Player
      
      timeA <- paste0('\\b', timeA, '\\b') 
      dados_gerais$timeA <- ifelse(grepl(paste(timeA, collapse = '|'), rownames(dados_gerais), useBytes = T), 1, 0)
      
      timeB <- paste0('\\b', timeB, '\\b') 
      dados_gerais$timeB <- ifelse(grepl(paste(timeB, collapse = '|'), rownames(dados_gerais), useBytes = T), 1, 0)
      
      timeA_df <- filter(dados_gerais, dados_gerais$timeA == 1)
      timeA_df <- dplyr::select(timeA_df, R, ACS, K.D, KAST, ADR)
      timeB_df <- filter(dados_gerais, dados_gerais$timeB == 1) 
      timeB_df <- dplyr::select(timeB_df, R, ACS, K.D, KAST, ADR)
      
      if(nrow(timeA_df) == 5 && nrow(timeB_df) == 5){
        
        # Médias
        timeA_R <- mean(timeA_df$R)
        timeA_ACS <- mean(timeA_df$ACS)
        timeA_KAST <- mean(timeA_df$KAST)
        timeA_KD <- mean(timeA_df$K.D)
        timeA_ADR <- mean(timeA_df$ADR)
        timeB_R <- mean(timeB_df$R)
        timeB_ACS <- mean(timeB_df$ACS)
        timeB_KAST <- mean(timeB_df$KAST)
        timeB_KD <- mean(timeB_df$K.D)
        timeB_ADR <- mean(timeB_df$ADR)
        
        partida <- c(timeA_R, timeB_R, timeA_ACS, timeB_ACS, timeA_KAST, timeB_KAST, timeA_KD, timeB_KD,
                     timeA_ADR, timeB_ADR)
        
        partida <- t(partida)
        
        partida <- as.data.frame(partida) %>% cbind(ganhador)
        
        colnames(partida) <- c('time1R', 'time2R', 'time1ACS', 'time2ACS', 'time1KAST', 'time2KAST', 'time1KD', 'time2KD',
                               'time1ADR', 'time2ADR', 'ganhador')
        
        return(partida)
      }
    }
    , error = function(e){cat('error:', conditionMessage(e), '\n')})
  
}

# Iteração para catalogar todos os jogos contidos nos urls armazenados --------------------------------------
for (i in a){
  tryCatch({
  dff[[length(dff)+1]] <- catalogarporUrl(a[m])
  m = m + 1
  }, error = function(e){cat('error:', conditionMessage(e), '\n')})
}

# Passando os dados recebidos para um dataframe mais organizado --------------------------------------------
dff <- dff %>% map_df(as_tibble)

# Exportando como csv --------------------------------------------------------------------------------------
write.csv2(dff, 'csv/partidas.csv')