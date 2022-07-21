require 'pry-byebug'

class Chess
  def initialize
    @board = Array.new(8) { Array.new(8, ' ') }
    fill_board
  end

  def space_filled?(pos)
    binding.pry
    x_pos = pos[0] - 1
    y_pos = 8 - pos[1]
    piece = board[y_pos][x_pos]
    return piece unless piece == ' '

    false
  end

  #private

  attr_accessor :board

  def fill_board
    piece_array = [Rook, Knight, Bishop, Queen, King, Bishop, Knight, Rook]
    board.each_with_index do |row, y_idx|
      8.times do |x_idx|
        case y_idx
        when 0
          row[x_idx] = piece_array[x_idx].new('Black', [8 - y_idx, x_idx + 1])
        when 1
          row[x_idx] = Pawn.new('Black', [8 - y_idx, x_idx + 1])
        when 6
          row[x_idx] = Pawn.new('White', [8 - y_idx, x_idx + 1])
        when 7
          row[x_idx] = piece_array[x_idx].new('White', [8 - y_idx, x_idx + 1])
        end
      end
    end
  end

  def print_board
    puts '   —————————————————————————————————'
    board.each_with_index do |row, y_idx|
      print "#{8 - y_idx}  | "
      row.each do |space|
        message = space == ' ' ? space : space.name
        print "#{message} | "
      end
      puts "\n   —————————————————————————————————"
    end
    puts '     1   2   3   4   5   6   7   8'
  end
end

class Player
  def initialize(board, name, color)
    @board = board
    @name = name.capitalize
    @color = color.capitalize
  end

  def validate_input
    loop do
      input = gets.chomp
      return input.split('').map(&:to_i) if /[1-8]{2}/.match?(input)

      puts 'Please enter a two-digit number in XY format.'
    end
  end

  def select_piece
    puts "#{name}'s turn"
    print 'Enter location to select piece: '
    loop do
      pos = validate_input
      piece = board.space_filled?(pos)
      return piece if piece && piece.color == color

      puts 'Invalid location entered.'
    end
  end

  private

  attr_reader :board, :name, :color
end

class Piece
  attr_reader :color, :name

  def initialize(color, pos)
    @color = color
    @pos = pos
  end
end

class Pawn < Piece
  def initialize(color, pos)
    super(color, pos)
    @name = 'P'
  end
end

class Rook < Piece
  def initialize(color, pos)
    super(color, pos)
    @name = 'R'
  end
end

class Knight < Piece
  def initialize(color, pos)
    super(color, pos)
    @name = 'K'
  end
end

class Bishop < Piece
  def initialize(color, pos)
    super(color, pos)
    @name = 'B'
  end
end

class Queen < Piece
  def initialize(color, pos)
    super(color, pos)
    @name = 'Q'
  end
end

class King < Piece
  def initialize(color, pos)
    super(color, pos)
    @name = 'K'
  end
end