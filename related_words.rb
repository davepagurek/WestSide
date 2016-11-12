#!/usr/bin/env ruby

require 'delegate'
require 'matrix'
require 'tf-idf-similarity'

require 'glove'

module WestSide
  class RelatedWords
    SOURCES = ['corpus.bin', 'cooc-matrix.bin', 'word-vec.bin', 'word-biases.bin']
      .map{|f| "preprocessed/#{f}"}

    def initialize(source = "sources/gatsby.txt")
      @source = source
    end

    def words
      @words ||= File.read(@source)
      .split(/\s+/)
      .map{|w| w.gsub(/\W/, '')}
      .to_set
    end

    def model
      return @model if @model

      @model = Glove::Model.new({
        max_count: 1000
      })

      SOURCES.each{|f| File.delete(f) if File.exists?(f)} if ENV["REPROCESS"]

      if SOURCES.all?{|f| File.exists?(f)}
        @model.load(*SOURCES)
      else
        text = File.read(@source)
        @model.fit(text)

        corpus = Glove::Corpus.build(text, {
          min_length: 2,
          min_count: 2,
        })
        @model.fit(corpus)

        @model.train

        @model.save(*SOURCES)
      end

      @model
    end

    def word_stems
      @word_stems ||= model.token_index.keys.to_set
      puts @word_stems.length
      @word_stems
    end

    def relatedness(a, b)
      puts word_stems.inspect
      vec_a = model.send(:vector, word_stems.find{|w| a.start_with?(w)})
      vec_b = model.send(:vector, word_stems.find{|w| b.start_with?(w)})

      return 0 unless vec_a && vec_b

      return model.send(:cosine, vec_a, vec_b)
    end

    def related_words(word, used = Set.new)
      (model.most_similar(word, 200).to_set - used)
        .map do |(stem, _)|
          words.find{|w| w.start_with?(stem)}
        end
        .compact
        .map{|w| w.gsub(/\W/, '')}
    end

    def related_word(word, used = Set.new)
      related_words(word, used)[0..20].sample || words.to_a.sample
    end
  end
end
