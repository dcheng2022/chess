require 'pry-byebug'

class Chess
  def initialize
    @board = Array.new(8) { Array.new(8, ' ') }
    fill_board
  end

  #private

  attr_accessor :board

  def fill_board
    piece_array = %w[r k b q k b k r]
    board.each_with_index do |row, y_idx|
      8.times do |x_idx|
        row[x_idx] = 'p' if [1, 6].include?(y_idx)
        row[x_idx] = piece_array[x_idx] if [0, 7].include?(y_idx)
      end
    end
  end

  def print_board
    puts '   —————————————————————————————————'
    board.each_with_index do |row, y_idx|
      print "#{8 - y_idx}  | "
      row.each do |space|
        message = space == ' ' ? space : space
        print "#{message} | "
      end
      puts "\n   —————————————————————————————————"
    end
    puts '     1   2   3   4   5   6   7   8'
  end
end

class Player
  def initialize(name, color)
    @name = name
    @color = color
  end

  def validate_input
    print "#{name}'s turn: "
    loop do
      input = gets.chomp
      return input.split('').map(&:to_i) if /[1-8]{2}/.match?(input) && ('11'..'88').include?(input)

      puts 'Please enter a two-digit number in XY format.'
    end
  end

  private

  attr_reader :name
end
