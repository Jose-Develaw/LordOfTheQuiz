//
//  ContentView.swift
//  lotrquiz
//
//  Created by José Ibáñez Bengoechea on 4/3/22.
//

import SwiftUI
import Combine

enum GameState {
    case mainMenu, playing, finalScore, topScores
}

struct ContentView: View {
    var allQuestions : [Question] = Bundle.main.decode("questions.json")
    
    @State private var topScores : TopScores = ScoreManager.getTopScores()
    
    @State private var gameState : GameState = .mainMenu
    @State private var gameQuestions = ArraySlice<Question>()
    @State private var currentRound = 0
    @State private var score = 0
    @State private var answered = false
    @State private var selectedOption = ""
    @State private var options = [String]()
    @State private var areButtonsDisabled = false
    
    //Timer and Score Graphics
    @State private var tickingAmount = 0.0
    @State private var remaining = 30
    @State private var showEye = false
    @State private var showCorrect = false
    
    //Timer
    @State var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State var connectedTimer: Cancellable? = nil
    
    @State private var userName = ""
    
    var body: some View {
        VStack{
            ZStack{
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color(.black)
                    .opacity(0.75)
                    .ignoresSafeArea()
                VStack{
                    Text("THE LORD OF THE QUIZ")
                        .font(.custom("Aniron", size: 26, relativeTo: .title))
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                    if (gameState == .mainMenu){
                        VStack{
                            Button{
                                withAnimation{
                                   initGame()
                                }
                            } label: {
                                Text("Iniciar partida")
                                    .buttonLabel()
                            }
                            Button{
                                withAnimation{
                                    gameState = .topScores
                                }
                            } label: {
                                Text("Ver puntuaciones")
                                    .buttonLabel()
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                        Spacer()
                       
                    }
                    if (gameState == .topScores){
                        VStack{
                            Text("Listado de puntuaciones")
                                .font(.custom("Aniron", size: 18, relativeTo: .headline))
                            ScrollView{
                                LazyVStack{
                                    ForEach(topScores.sortedScores, id: \.self) { score in
                                        HStack (alignment: .lastTextBaseline){
                                            Text(score.userName)
                                                .font(.custom("Aniron", size: 16, relativeTo: .headline))
                                            Spacer()
                                            Text(score.score, format: .number)
                                                .font(.custom("Aniron", size: 16, relativeTo: .headline))
                                        }
                                    }
                                }
                            }
                            .padding()
                            
                            Button{
                                withAnimation{
                                    gameState = .mainMenu
                                }
                            } label: {
                                Text("Volver al menú")
                                    .buttonLabel()
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                        Spacer()
                    }
                    
                    if (gameState == .finalScore){
                        VStack{
                            Spacer()
                            Text("Puntuación final: \(score)")
                                .font(.custom("Aniron", size: 18, relativeTo: .headline))
                            TextField("Escribe tu nombre", text: $userName)
                                .multilineTextAlignment(.center)
                                .accentColor(Color(red: 168/255, green: 147/255, blue: 36/255, opacity: 0.6))
                                .padding(.horizontal)
                                .buttonLabel()
                            Spacer()
                            Button{
                                let newScore = Score(userName: userName, score: score)
                                topScores.scores.append(newScore)
                                ScoreManager.saveTopScores(topScores)
                                withAnimation{
                                    gameState = .mainMenu
                                }
                            } label: {
                                Text("Guardar puntuación")
                                    .foregroundColor(userName.count <= 0 ? .gray : .white)
                                    .buttonLabel()
                                    
                            }
                            .disabled(userName.count <= 0)
                            
                            Button{
                                withAnimation{
                                    gameState = .mainMenu
                                }
                            } label: {
                                Text("Salir sin guardar")
                                    .buttonLabel()
                            }
                            Spacer()
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                        Spacer()
                    }
                    
                    if (gameQuestions != [] && gameState == .playing){
                        VStack{
                            Spacer()
                            RingTimer(tickingAmount: $tickingAmount, remaining: $remaining, showEye: $showEye, showCorrect: $showCorrect)
                            Spacer()
                            VStack{
                                Spacer()
                                VStack(alignment: .center){
                                    Text(gameQuestions[currentRound].question)
                                        .font(.custom("Aniron", size: 16, relativeTo: .headline))
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                ForEach(options, id: \.self){option in
                                    Button{
                                        areButtonsDisabled = true
                                        Task.init(priority: .high) {
                                            cancelTimer()
                                            await answerQuestion(option)
                                        }
                                    } label: {
                                        AnswerButton(resolvedColor: resolveColor(option), option: option)
                                    }
                                    .disabled(areButtonsDisabled)
                                }
                                
                            }
                            .frame(maxHeight: .infinity)
                            Text("Puntuación: \(score)")
                                .font(.custom("Aniron", size: 18, relativeTo: .headline))
                                .padding()
                            
                        }
                        .onReceive(timer){ _ in
                            if (remaining > 0 && !answered) {
                                withAnimation(.linear(duration: 1)){
                                    tickingAmount += 12
                                }
                                remaining -= 1
                            } else {
                                cancelTimer()
                                withAnimation{
                                    showEye = true
                                }
                                areButtonsDisabled = true
                                Task.init(priority: .high) {
                                    await answerQuestion("")
                                }
                            }
                            
                        }
                        
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    }
                }
                .padding(15)
                .frame(maxWidth: 550, maxHeight: 800)
            }
        }
        .preferredColorScheme(.dark)
        
    }
    
    func instantiateTimer() {
            self.timer = Timer.publish(every: 1, on: .main, in: .common)
            self.connectedTimer = self.timer.connect()
            return
    }
        
    func cancelTimer() {
        self.connectedTimer?.cancel()
        return
    }
    
    func nextRound(){
        remaining = 30
        currentRound += 1
        selectedOption = ""
        answered = false
        options = gameQuestions[currentRound].options.shuffled()
        tickingAmount = 0.0
        instantiateTimer()
        areButtonsDisabled = false
        showCorrect = false
        withAnimation{
            showEye = false
        }
    }
    
    func initGame(){
        currentRound = 0
        score = 0
        showCorrect = false
        showEye = false
        gameQuestions = allQuestions.shuffled()[..<10]
        options = gameQuestions[currentRound].options.shuffled()
        instantiateTimer()
        gameState = .playing
    }
    
    func answerQuestion(_ option: String) async {
        withAnimation{
            selectedOption = option
            answered = true
        }
        if(option == gameQuestions[currentRound].correctAnswer){
                showCorrect = true
                score += remaining
        } else {
            withAnimation{
                showEye = true
            }
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if(currentRound < 9){
            nextRound()
        } else {
            gameState = .finalScore
        }
    }
    
    
    
    func resolveColor(_ option: String) -> Color {
        if(!answered){
            return Color(red: 168/255, green: 147/255, blue: 36/255, opacity: 0.6)
        }
        if(option == gameQuestions[currentRound].correctAnswer){
            return .green
        } else if (option != gameQuestions[currentRound].correctAnswer && option == selectedOption){
            return .red
        }
        return Color(red: 168/255, green: 147/255, blue: 36/255, opacity: 0.6)
    }
        
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
