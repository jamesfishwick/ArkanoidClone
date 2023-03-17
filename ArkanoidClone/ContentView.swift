import SwiftUI
import Combine

struct ContentView: View {
    var body: some View {
        StartScreen()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct SafeAreaInsetsKey: PreferenceKey {
    static var defaultValue: EdgeInsets = .init()

    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

struct StartScreen: View {
    @State private var showGameView = false
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        VStack {
            Text("Arkanoid Clone")
                .font(.largeTitle)
                .bold()
                .padding()

            Button(action: {
                showGameView.toggle()
            }) {
                Text("Start")
                    .font(.title)
                    .padding()
            }
            .sheet(isPresented: $showGameView) {
                GameView(viewModel: viewModel)
            }
        }
    }
}








// GameViewModel.swift
class GameViewModel: ObservableObject {
    @Published var bricks: [Brick] = {
            var bricksArray = [Brick]()
            for i in 0..<6 * 10 {
                bricksArray.append(Brick(id: i, hit: false))
            }
            return bricksArray
        }()
    @Published var ballPosition: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 100 - 20)
    @Published var paddlePosition: CGFloat = UIScreen.main.bounds.width / 2
    @Published var ballAttachedToPaddle: Bool = true
    
        let ballRadius: CGFloat = 10
        let brickWidth: CGFloat = 60
        let brickHeight: CGFloat = 20
        let paddleWidth: CGFloat = 100
        let paddleHeight: CGFloat = 20
        let paddleBottomOffset: CGFloat = 50

    private var ballDirection: CGVector = CGVector(dx: 2, dy: -2)
    private var gameRunLoop: AnyCancellable?
    private let acceleration: CGFloat = 1.05
    private var safeAreaInsets: EdgeInsets
    private func isCollidingWithBrick(_ brick: Brick) -> Bool {
        

        let brickPos = brickPosition(for: brick.id)

        let minX = brickPos.x - brickWidth / 2 - ballRadius
        let maxX = brickPos.x + brickWidth / 2 + ballRadius
        let minY = brickPos.y - brickHeight / 2 - ballRadius
        let maxY = brickPos.y + brickHeight / 2 + ballRadius

        return ballPosition.x >= minX && ballPosition.x <= maxX && ballPosition.y >= minY && ballPosition.y <= maxY
    }
    
    func brickPosition(for id: Int) -> CGPoint {

        let brickX = CGFloat(30 + (id % 10) * 65)
        let brickY = CGFloat(60 + (id / 10) * 30)

        return CGPoint(x: brickX, y: brickY)
    }

    init() {
        if let uiEdgeInsets = UIApplication.shared.windows.first?.safeAreaInsets {
                    self.safeAreaInsets = EdgeInsets(top: uiEdgeInsets.top, leading: uiEdgeInsets.left, bottom: uiEdgeInsets.bottom, trailing: uiEdgeInsets.right)
                } else {
                    self.safeAreaInsets = EdgeInsets()
                }
        resetBallPosition()
        let timer = Timer.publish(every: 0.01, on: .main, in: .common)
        gameRunLoop = timer.autoconnect().sink { [weak self] _ in
            self?.updateGame()
        }
    }
    
    private func resetBallPosition() {
        let paddleY = UIScreen.main.bounds.height - safeAreaInsets.bottom - 60
        ballPosition = CGPoint(x: paddlePosition, y: paddleY - 15)
    }
    
    private func launchBall() {
        let angle = CGFloat.random(in: 30..<150) * (.pi / 180)
        ballDirection = CGVector(dx: cos(angle) * 2, dy: -sin(angle) * 2)
        ballAttachedToPaddle = false
    }


    private func updateGame() {
        ballPosition = CGPoint(x: ballPosition.x + ballDirection.dx, y: ballPosition.y + ballDirection.dy)
        
        if ballAttachedToPaddle {
                resetBallPosition()
            } else {
                ballPosition = CGPoint(x: ballPosition.x + ballDirection.dx, y: ballPosition.y + ballDirection.dy)
            }

        // Check for wall collisions
        if ballPosition.x <= 10 || ballPosition.x >= UIScreen.main.bounds.width - 10 {
            ballDirection.dx = -ballDirection.dx
        }

        if ballPosition.y <= 10 {
            ballDirection.dy = -ballDirection.dy
        }

        // Check for paddle collision
        let paddleLeftEdge = paddlePosition - paddleWidth / 2
        let paddleRightEdge = paddlePosition + paddleWidth / 2
        let paddleTopEdge = UIScreen.main.bounds.height - safeAreaInsets.bottom - paddleBottomOffset - paddleHeight
        let ballRadius: CGFloat = 10

        if ballDirection.dy > 0 &&
            ballPosition.y + ballRadius >= paddleTopEdge &&
            ballPosition.y - ballRadius < paddleTopEdge &&
            ballPosition.x + ballRadius >= paddleLeftEdge &&
            ballPosition.x - ballRadius <= paddleRightEdge {
            ballDirection.dy = -ballDirection.dy
        }

        // Check for brick collisions
        if let index = bricks.firstIndex(where: { !($0.hit) && isCollidingWithBrick($0) }) {
            bricks[index].hit = true
            collideWithBrick(at: index)
        }
    }

    func collideWithBrick(at index: Int) {
        ballDirection.dx *= acceleration
        ballDirection.dy *= acceleration
        ballDirection.dy = -ballDirection.dy
    }
    
    func onTapGesture() {
        if ballAttachedToPaddle {
            launchBall()
        }
    }
}

struct Brick: Identifiable {
    var id: Int
    var hit: Bool
}


struct GameView: View {
    @GestureState private var dragOffset = CGSize.zero
        @StateObject private var viewModel: GameViewModel
        @State private var safeAreaInsets: EdgeInsets = EdgeInsets()
        
        let ballRadius: CGFloat
        let paddleWidth: CGFloat
        let paddleHeight: CGFloat
        let paddleBottomOffset: CGFloat

        init(viewModel: GameViewModel) {
            _viewModel = StateObject(wrappedValue: viewModel)
            ballRadius = viewModel.ballRadius
            paddleWidth = viewModel.paddleWidth
            paddleHeight = viewModel.paddleHeight
            paddleBottomOffset = viewModel.paddleBottomOffset
        }

    struct SafeAreaInsetsKey: PreferenceKey {
        static var defaultValue: EdgeInsets = EdgeInsets()

        static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
            value = nextValue()
        }
    }
    

    var body: some View {
        GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .edgesIgnoringSafeArea(.all)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: SafeAreaInsetsKey.self, value: geometry.safeAreaInsets)
                        })
                        .onPreferenceChange(SafeAreaInsetsKey.self) { value in
                            safeAreaInsets = value
                        }

                    Paddle()
                        .frame(width: viewModel.paddleWidth, height: viewModel.paddleHeight)
                                            .position(CGPoint(x: viewModel.paddlePosition, y: UIScreen.main.bounds.height - safeAreaInsets.bottom - viewModel.paddleBottomOffset))
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        let newPosition = viewModel.paddlePosition + value.translation.width
                                                        viewModel.paddlePosition = min(max(newPosition, 50), UIScreen.main.bounds.width - 50)
                                                    }
                                            )
                    ForEach(viewModel.bricks) { brick in
                        if !brick.hit {
                            BrickView()
                                .position(viewModel.brickPosition(for: brick.id))
                        }
                    }

                    Ball()
                        .frame(width: viewModel.ballRadius * 2, height: viewModel.ballRadius * 2)
                        .position(viewModel.ballPosition)

            }
            
                .onTapGesture {
                            viewModel.onTapGesture()
                        }
        }
    }
}



struct Paddle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .frame(width: 100, height: 20)
            .foregroundColor(.white)
    }
}



    struct Ball: View {
        var body: some View {
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)
        }
    }

struct BrickView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .frame(width: 60, height: 20)
            .foregroundColor(.green)
    }
}
