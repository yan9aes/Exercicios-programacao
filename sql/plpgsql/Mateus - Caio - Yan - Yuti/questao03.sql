------------------------ Questão nº3 ------------------------
-- Faça uma função que estime a chance de um livro ser devolvido 
-- com atraso, considerando o histórico do usuário, o tipo de 
-- livro (gênero) e o número de páginas. A função deve utilizar 
-- classificação binária (por exemplo, regressão logística) e 
-- ter o seguinte formato:
-- 
--     probabilidade_atraso(nome_usuário, gênero, num_páginas)
-- 
-- A saída deve ser um valor entre 0 e 1 representando a chance 
-- estimada de atraso.

CREATE OR REPLACE FUNCTION biblio.probabilidade_devolucao(
    biblioteca_id INTEGER
)
RETURNS SETOF RECORD 
LANGUAGE plpgsql 
AS $$
DECLARE
    generos TEXT;
    query TEXT;
BEGIN
    -- Obtem lista de gêneros formatada para a seleção
    SELECT STRING_AGG(
        'COALESCE(MAX(CASE WHEN genero_id = ' || pk || ' THEN probabilidade END), 0.5) AS "' || nome || '"',
        ', '
    )
    INTO generos
    FROM biblio.Genero;

    -- Constrói uma query dinâmica para lidar com quantdade incerta de gêneros
    query := '
    WITH dados_emprestimos AS (
        SELECT 
            c.pk AS usuario_id,
            l.pk_genero AS genero_id,
            g.nome AS genero_nome,
            CASE WHEN e.data_entrega <= e.data_prevista THEN 1 ELSE 0 END AS devolucao_pontual
        FROM 
            biblio.Emprestimo e
            JOIN biblio.Cliente c ON e.pk_cliente = c.pk
            JOIN biblio.CopiaLivro cl ON e.pk_copia_livro = cl.pk
            JOIN biblio.Livro l ON cl.pk_livro = l.pk
            JOIN biblio.Genero g ON l.pk_genero = g.pk
        WHERE 
            cl.pk_biblioteca = ' || biblioteca_id || '
            AND e.data_entrega IS NOT NULL
    ),
    estatisticas AS (
        SELECT 
            usuario_id,
            genero_id,
            genero_nome,
            (SUM(devolucao_pontual) + 1)::NUMERIC / 
            (COUNT(*) + 2) AS probabilidade
        FROM 
            dados_emprestimos
        GROUP BY 
            usuario_id, genero_id, genero_nome
    ),
    todos_usuarios AS (
        SELECT DISTINCT c.pk AS id, c.nome
        FROM biblio.Cliente c
        JOIN biblio.Emprestimo e ON c.pk = e.pk_cliente
        JOIN biblio.CopiaLivro cl ON e.pk_copia_livro = cl.pk
        WHERE cl.pk_biblioteca = ' || biblioteca_id || '
    )
    SELECT 
        u.id AS usuario_id,
        u.nome AS usuario_nome, ' || generos || '
    FROM 
        todos_usuarios u
        LEFT JOIN estatisticas e ON u.id = e.usuario_id
    GROUP BY 
        u.id, u.nome
    ORDER BY 
        u.nome';

    RETURN QUERY EXECUTE query;
END;
$$;

SELECT * FROM biblio.probabilidade_devolucao(3) 
AS (
    usuario_id INTEGER,
    usuario_nome TEXT,
    Fantasia NUMERIC,
    Mistério NUMERIC,
    Aventura NUMERIC,
    "Ficção Científica" NUMERIC,
    Drama NUMERIC,
    Romance NUMERIC,
    Infantil NUMERIC,
    História NUMERIC,
    Biografia NUMERIC
);
