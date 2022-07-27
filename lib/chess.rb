require 'pry-byebug'

class Chess
  def initialize
    @board = Array.new(8) { Array.new(8, ' ') }
    fill_board
  end

  def space_filled?(pos)
    x_pos = pos[0] - 1
    y_pos = 8 - pos[1]
    piece = board[y_pos][x_pos]
    return piece unless piece == ' '

    false
  end

  def modify_board(row, column, value)
    x_pos = row - 1
    y_pos = 8 - column
    board[y_pos][x_pos] = value
  end

  #private

  attr_accessor :board

  def fill_board
    piece_array = [Rook, Knight, Bishop, Queen, King, Bishop, Knight, Rook]
    board.each_with_index do |row, y_idx|
      8.times do |x_idx|
        case y_idx
        when 0
          row[x_idx] = piece_array[x_idx].new(self, 'Black', [x_idx + 1, 8 - y_idx])
        when 1
          row[x_idx] = Pawn.new(self, 'Black', [x_idx + 1, 8 - y_idx])
        when 6
          row[x_idx] = Pawn.new(self, 'White', [x_idx + 1, 8 - y_idx])
        when 7
          row[x_idx] = piece_array[x_idx].new(self, 'White', [x_idx + 1, 8 - y_idx])
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
      moves = piece ? piece.find_moves : false
      return [piece, moves] if moves && piece.color == color

      puts 'Invalid location entered.'
    end
  end

  def move_piece
    info_array = select_piece
    piece = info_array[0]
    moves = info_array[1]
    print 'Enter location to move piece: '
    loop do
      pos = validate_input
      if moves.include?(pos)
        puts "#{name} moved #{piece.name} to #{piece.change_pos(pos)}"
        break
      end
      puts 'Invalid location entered.'
    end
  end

  private

  attr_reader :board, :name, :color
end

class Piece
  attr_reader :color, :shift_set, :name
  attr_accessor :pos

  def initialize(board, color, pos)
    @board = board
    @color = color
    @pos = pos
  end

  def find_moves
    valid_moves = []
    if %w[B R Q].include?(name)
      valid_moves.concat(find_BRQ_moves)
    else
      valid_moves.concat(pawn_attack).concat(first_move) if name == 'P'
      shift_set.each do |shift|
        move_info = find_move_info(shift)
        next unless move_info

        valid_moves << move_info[:move] unless move_info[:piece] && (move_info[:piece].color == color || name == 'P')
      end
    end
    valid_moves.empty? ? false : valid_moves
  end

  def change_pos(destination)
    promote_pawn = true if [1, 8].include?(destination[1]) && name == 'P'
    piece = promote_pawn ? promote_set[promote_input].new(board, color, destination) : self

    locations = [pos, destination]
    locations.each_with_index do |location, pass|
      value = pass.zero? ? ' ' : piece
      board.modify_board(location[0], location[1], value)
    end
    # once castling implemented also add K and R
    self.moved = true if %w[P].include?(name)
    self.pos = destination
  end

  private

  attr_reader :board

  def find_BRQ_moves
    valid_moves = []
    shift_set.each do |diagonal|
      diagonal.each do |shift|
        move_info = find_move_info(shift)
        next unless move_info

        break if move_info[:piece] && move_info[:piece].color == color

        valid_moves << move_info[:move]
        break if move_info[:piece]
      end
    end
    valid_moves
  end

  def find_move_info(shift)
    move = [pos[0] + shift[0], pos[1] + shift[1]]
    return false unless in_bounds?(move)

    piece = board.space_filled?(move)
    piece ? { move: move, piece: piece } : { move: move, piece: false }
  end

  def in_bounds?(move)
    true if move.all? { |coord| (1..8).include?(coord) }
  end
end

class Pawn < Piece
  attr_reader :promote_set
  attr_accessor :moved

  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'P'
    @shift_set = create_shifts
    @moved = false
    @promote_set = [Knight, Bishop, Rook, Queen]
  end

  def create_shifts
    shifts = { 'White' => [[0, 1]], 'Black' => [[0, -1]] }
    shifts[color]
  end

  def first_move
    return [] if moved

    shift = shift_set.flatten
    [[pos[0], pos[1] + 2 * shift[1]]]
  end

  def pawn_attack
    valid_attacks = []
    shifts = { 'White' => [[-1, 1], [1, 1]], 'Black' => [[-1, -1], [1, -1]] }
    shifts[color].each do |shift|
      move_info = find_move_info(shift)
      next unless move_info && move_info[:piece]

      valid_attacks << move_info[:move] unless move_info[:piece].color == color
    end
    valid_attacks.empty? ? [] : valid_attacks
  end

  private

  def promote_input
    pieces = %w[Knight Bishop Rook Queen]
    print 'Enter the full name of the piece you desire to promote your pawn into: '
    loop do
      input = gets.chomp.capitalize
      return pieces.index(input) if pieces.include?(input)

      puts 'Invalid piece entered.'
    end
  end
end

class Rook < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'R'
    @shift_set = create_shifts
  end

  def create_shifts
    left_temp = []
    right_temp = []
    (1..7).each do |num|
      left_temp << [0 - num, 0]
      right_temp << [num, 0]
    end
    [left_temp, right_temp, left_temp.map(&:rotate), right_temp.map(&:rotate)]
  end
end

class Knight < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'K'
    @shift_set = create_shifts
  end

  def create_shifts
    temp = []
    [-2, -1, 1, 2].permutation(2) { |perm| temp << perm }
    temp.reject { |perm| perm[0].abs == perm[1].abs }
  end
end

class Bishop < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'B'
    @shift_set = create_shifts
  end

  def create_shifts
    bot_left_temp = []
    bot_right_temp = []
    (1..7).each do |num|
      bot_left_temp << [0 - num, 0 - num]
      bot_right_temp << [num, 0 - num]
    end
    [bot_left_temp, bot_right_temp, bot_left_temp.map { |shift| shift.map(&:abs) }, bot_right_temp.map(&:rotate)]
  end
end

class Queen < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'Q'
    @shift_set = create_shifts
  end

  def create_shifts
    temp_rook = Rook.new(nil, nil, nil)
    temp_bishop = Bishop.new(nil, nil, nil)
    temp_rook.shift_set.concat(temp_bishop.shift_set)
  end
end

class King < Piece
  def initialize(board, color, pos)
    super(board, color, pos)
    @name = 'K'
    @shift_set = create_shifts
  end

  def create_shifts
    temp = []
    [-1, -1, 0, 1, 1].permutation(2) { |perm| temp << perm }
    temp.uniq
  end
end
